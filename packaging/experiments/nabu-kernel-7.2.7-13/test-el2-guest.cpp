// Test-only init for a disposable QEMU virt machine. Never packaged for Nabu.
// It exercises the real kernel's KVM UAPI; it is not a firmware transition.
#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <linux/kvm.h>
#include <sched.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <unistd.h>

static bool is_qemu = false;

[[noreturn]] static void finish(bool success, const char *message)
{
    std::printf("NABU_EL2_TEST_%s: %s\n", success ? "PASS" : "FAIL", message);
    std::fflush(stdout);
    if (is_qemu)
        reboot(RB_POWER_OFF);
    _exit(success ? 0 : 1);
}

static void require(bool condition, const char *operation)
{
    if (!condition) {
        std::printf("operation=%s errno=%d (%s)\n", operation, errno, std::strerror(errno));
        finish(false, operation);
    }
}

struct Fd {
    int value;
    explicit Fd(int fd) : value(fd) { require(fd >= 0, "open/create fd"); }
    ~Fd() { close(value); }
    Fd(const Fd &) = delete;
    Fd &operator=(const Fd &) = delete;
};

struct Mapping {
    void *address;
    std::size_t size;
    Mapping(std::size_t length, int flags, int fd) :
        address(mmap(nullptr, length, PROT_READ | PROT_WRITE, flags, fd, 0)), size(length)
    { require(address != MAP_FAILED, "mmap"); }
    ~Mapping() { munmap(address, size); }
    Mapping(const Mapping &) = delete;
    Mapping &operator=(const Mapping &) = delete;
};

static std::size_t read_file(const char *path, char *buffer, std::size_t size)
{
    Fd file(open(path, O_RDONLY | O_CLOEXEC));
    const ssize_t count = read(file.value, buffer, size - 1);
    require(count >= 0, "read file");
    buffer[count] = '\0';
    return static_cast<std::size_t>(count);
}

static void set_register(int vcpu, std::uint64_t index, std::uint64_t value)
{
    kvm_one_reg reg{};
    reg.id = KVM_REG_ARM64 | KVM_REG_SIZE_U64 | KVM_REG_ARM_CORE | index;
    reg.addr = reinterpret_cast<std::uintptr_t>(&value);
    require(ioctl(vcpu, KVM_SET_ONE_REG, &reg) == 0, "KVM_SET_ONE_REG");
}

// Real AArch64 guest instructions, assembled by the target toolchain.
// RAM is at 0x40000000; an unmapped address produces an observable MMIO exit.
extern "C" const char nabu_test_guest[];
asm(".pushsection .rodata\n"
    ".balign 4\n"
    ".global nabu_test_guest\n"
    "nabu_test_guest:\n"
    "movz x0, #0x1000, lsl #16\n"
    "movz w1, #0x4b56\n"
    "str w1, [x0]\n"
    "b .\n"
    ".popsection\n");

static void run_guest(int kvm, int cpu)
{
    cpu_set_t affinity;
    CPU_ZERO(&affinity);
    CPU_SET(cpu, &affinity);
    require(sched_setaffinity(0, sizeof(affinity), &affinity) == 0, "pin host CPU");

    Fd vm(ioctl(kvm, KVM_CREATE_VM, 0));
    const long page_size = sysconf(_SC_PAGESIZE);
    require(page_size >= 4096, "host page size");
    Mapping memory(static_cast<std::size_t>(page_size), MAP_PRIVATE | MAP_ANONYMOUS, -1);
    std::memcpy(memory.address, nabu_test_guest, 16);
    kvm_userspace_memory_region region{};
    region.guest_phys_addr = 0x40000000;
    region.memory_size = memory.size;
    region.userspace_addr = reinterpret_cast<std::uintptr_t>(memory.address);
    require(ioctl(vm.value, KVM_SET_USER_MEMORY_REGION, &region) == 0, "KVM_SET_USER_MEMORY_REGION");

    kvm_create_device create{};
    create.type = KVM_DEV_TYPE_ARM_VGIC_V3;
    require(ioctl(vm.value, KVM_CREATE_DEVICE, &create) == 0, "create virtual GICv3");
    Fd vgic(static_cast<int>(create.fd));
    std::uint64_t distributor = 0x08000000, redistributor = 0x080a0000;
    kvm_device_attr attr{};
    attr.group = KVM_DEV_ARM_VGIC_GRP_ADDR;
    attr.attr = KVM_VGIC_V3_ADDR_TYPE_DIST;
    attr.addr = reinterpret_cast<std::uintptr_t>(&distributor);
    require(ioctl(vgic.value, KVM_SET_DEVICE_ATTR, &attr) == 0, "VGIC distributor");
    attr.attr = KVM_VGIC_V3_ADDR_TYPE_REDIST;
    attr.addr = reinterpret_cast<std::uintptr_t>(&redistributor);
    require(ioctl(vgic.value, KVM_SET_DEVICE_ATTR, &attr) == 0, "VGIC redistributor");

    Fd vcpu(ioctl(vm.value, KVM_CREATE_VCPU, 0));
    kvm_vcpu_init init{};
    require(ioctl(vm.value, KVM_ARM_PREFERRED_TARGET, &init) == 0, "KVM_ARM_PREFERRED_TARGET");
    require(ioctl(vcpu.value, KVM_ARM_VCPU_INIT, &init) == 0, "KVM_ARM_VCPU_INIT");
    attr = {};
    attr.group = KVM_DEV_ARM_VGIC_GRP_CTRL;
    attr.attr = KVM_DEV_ARM_VGIC_CTRL_INIT;
    require(ioctl(vgic.value, KVM_SET_DEVICE_ATTR, &attr) == 0, "initialize virtual GIC");
    set_register(vcpu.value, KVM_REG_ARM_CORE_REG(regs.pc), region.guest_phys_addr);
    set_register(vcpu.value, KVM_REG_ARM_CORE_REG(regs.pstate), 0x3c5); // EL1h, DAIF masked

    const int run_size = ioctl(kvm, KVM_GET_VCPU_MMAP_SIZE, 0);
    require(run_size >= static_cast<int>(sizeof(kvm_run)), "KVM_GET_VCPU_MMAP_SIZE");
    Mapping run_memory(static_cast<std::size_t>(run_size), MAP_SHARED, vcpu.value);
    auto *run = static_cast<kvm_run *>(run_memory.address);
    alarm(20);
    const int result = ioctl(vcpu.value, KVM_RUN, 0);
    alarm(0);
    require(result == 0, "KVM_RUN (20-second bound)");
    require(run->exit_reason == KVM_EXIT_MMIO && run->mmio.is_write &&
            run->mmio.phys_addr == 0x10000000 && run->mmio.len == 4,
            "guest MMIO exit");
    std::uint32_t value = 0;
    std::memcpy(&value, run->mmio.data, sizeof(value));
    require(value == 0x4b56, "guest result value");
    std::printf("NABU_EL2_GUEST: host-cpu=%d guest-wrote=0x%x\n", cpu, value);
    std::fflush(stdout);
}

static void interrupted(int) {} // Interrupt KVM_RUN without SA_RESTART.

int main()
{
    if (getpid() != 1) {
        std::fprintf(stderr, "This test may run only as disposable QEMU init.\n");
        return 2;
    }
    require(mount("devtmpfs", "/dev", "devtmpfs", 0, nullptr) == 0, "mount devtmpfs");
    Fd console(open("/dev/console", O_RDWR | O_CLOEXEC));
    for (int fd = 0; fd < 3; ++fd)
        require(dup2(console.value, fd) == fd, "console stdio");
    require(mount("proc", "/proc", "proc", MS_NOSUID | MS_NODEV | MS_NOEXEC, nullptr) == 0, "mount proc");
    require(mount("sysfs", "/sys", "sysfs", MS_NOSUID | MS_NODEV | MS_NOEXEC, nullptr) == 0, "mount sysfs");
    char compatible[512];
    read_file("/sys/firmware/devicetree/base/compatible", compatible, sizeof(compatible));
    require(std::strcmp(compatible, "linux,dummy-virt") == 0, "QEMU virt only; refuse physical hardware");
    is_qemu = true;
    char command_line[4096];
    read_file("/proc/cmdline", command_line, sizeof(command_line));
    const bool expect_el1 = std::strstr(command_line, "nabu_test.expect=el1") != nullptr;
    const bool expect_el2 = std::strstr(command_line, "nabu_test.expect=el2") != nullptr;
    require(expect_el1 != expect_el2, "exactly one test expectation required");
    require(sysconf(_SC_NPROCESSORS_ONLN) == 8, "all eight CPUs must be online");
    const int kvm_fd = open("/dev/kvm", O_RDWR | O_CLOEXEC);
    if (expect_el1) {
        require(kvm_fd < 0 && (errno == ENOENT || errno == ENODEV), "EL1 must not expose working KVM");
        finish(true, "EL1 rejects KVM; all 8 CPUs online");
    }
    Fd kvm(kvm_fd);
    require(ioctl(kvm.value, KVM_GET_API_VERSION, 0) == KVM_API_VERSION, "KVM API version");
    struct sigaction action{};
    action.sa_handler = interrupted;
    sigemptyset(&action.sa_mask);
    require(sigaction(SIGALRM, &action, nullptr) == 0, "install guest timeout");
    for (int cpu = 0; cpu < 8; ++cpu)
        run_guest(kvm.value, cpu);
    finish(true, "EL2 KVM guest executed on all 8 host CPUs");
}
