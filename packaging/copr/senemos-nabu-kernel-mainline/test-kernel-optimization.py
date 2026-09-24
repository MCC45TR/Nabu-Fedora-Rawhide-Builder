#!/usr/bin/env python3
"""Build-host tests only; no tablet runtime, MMIO or hardware access.

Compile the actual MSM suspend function with contract-checking mocks. Check
the resolved Kconfig and compiled DT, not just the input configuration fragment.
This is not a concurrency, power-consumption or physical suspend test.
"""
import copy
import os
from pathlib import Path
import re
import resource
import runpy
import shlex
import subprocess
import sys
import tempfile


def check_config(config):
    expected = {
        "NR_CPUS": "8", "SMP": "y", "HOTPLUG_CPU": "y",
        "ENERGY_MODEL": "y", "CPU_FREQ_DEFAULT_GOV_SCHEDUTIL": "y",
        "CPU_IDLE": "y", "ARM_PSCI_CPUIDLE": "y", "NO_HZ_IDLE": "y",
        "PREEMPT": "y", "HZ_250": "y", "WQ_POWER_EFFICIENT_DEFAULT": "y",
        "LRU_GEN": "y", "LRU_GEN_ENABLED": "y", "ZRAM": "m",
        "ZRAM_DEF_COMP_ZSTD": "y", "CMA_SIZE_MBYTES": "256",
        "ARM_QCOM_CPUFREQ_HW": "y", "QCOM_TSENS": "y",
        "THERMAL": "y", "CPU_THERMAL": "y", "DEVFREQ_THERMAL": "y",
        "SECURITY_SELINUX": "y", "BPF_LSM": "y",
        "MODULE_SIG": "y", "ARM_SMMU_DISABLE_BYPASS_BY_DEFAULT": "y",
        "NUMA": None, "NUMA_BALANCING": None, "CPUMASK_OFFSTACK": None,
        "ZSWAP": None,
    }
    for name, value in expected.items():
        assert config.get("CONFIG_" + name) == value, f"unexpected CONFIG_{name}"


def check_topology(nodes, cells):
    cpus = sorted((n for n in nodes.values() if n.get("device_type") == b"cpu\0"),
                  key=lambda n: cells(n["reg"]))
    assert len(cpus) == 8
    for i, cpu in enumerate(cpus):
        domain = 0 if i < 4 else 1 if i < 7 else 2
        assert cells(cpu["clocks"])[1:] == (domain,), "CPU frequency policy changed"
        assert cpu["clocks"] == cpu["qcom,freq-domain"]
        assert cells(cpu["dynamic-power-coefficient"]) == ((232 if i < 4 else 369 if i < 7 else 421),)
        assert cells(cpu["capacity-dmips-mhz"]) == ((488 if i < 4 else 1024),)
        assert cells(cpu["#cooling-cells"]) == (2,)
    assert len({cells(cpu["clocks"])[0] for cpu in cpus}) == 1
    memory = [n for n in nodes.values() if n.get("device_type") == b"memory\0"]
    assert memory, "missing memory node"
    for node in cpus + memory:
        assert cells(node.get("numa-node-id", bytes(4))) == (0,), "NUMA needs a config re-audit"


def test_suspend(source):
    match = re.search(r"^void msm_devfreq_suspend\(struct msm_gpu \*gpu\)\n\{.*?^\}", source, re.M | re.S)
    assert match, "MSM suspend entry point not found"
    function = match.group()
    prefix = r'''
#include <assert.h>
#include <stdbool.h>
struct mutex { bool held; };
struct dev_pm_qos_request { int value; };
struct msm_gpu_devfreq {
    struct mutex lock;
    bool suspended;
    void *devfreq;
    struct dev_pm_qos_request boost_freq;
};
struct msm_gpu { struct msm_gpu_devfreq devfreq; };
static struct msm_gpu_devfreq *current;
static int phase;
static bool has_devfreq(struct msm_gpu *gpu) { return gpu->devfreq.devfreq != 0; }
static void mutex_lock(struct mutex *lock) { assert(!lock->held); lock->held = true; }
static void mutex_unlock(struct mutex *lock) { assert(lock->held); lock->held = false; }
static void devfreq_suspend_device(void *df) {
    assert(df && current->suspended && !current->lock.held && phase == 0);
    phase = 1;
}
static void cancel_idle_work(struct msm_gpu_devfreq *df) {
    assert(df == current && phase == 1); phase = 2;
}
static void cancel_boost_work(struct msm_gpu_devfreq *df) {
    assert(df == current && phase == 2); phase = 3;
}
static int dev_pm_qos_update_request(struct dev_pm_qos_request *request, int value) {
    assert(request == &current->boost_freq && !value);
    assert(current->suspended && !current->lock.held && phase == 3);
    request->value = value; phase = 4; return 0;
}
'''
    suffix = r'''
int main(void) {
    struct msm_gpu gpu = {0};
    current = &gpu.devfreq;
    current->boost_freq.value = 675000;
    msm_devfreq_suspend(&gpu);
    assert(!current->suspended && !phase && current->boost_freq.value == 675000);
    current->devfreq = current;
    for (int i = 0; i < 10000; i++) {
        current->suspended = false; phase = 0;
        current->boost_freq.value = i % 2 ? 675000 : 0;
        msm_devfreq_suspend(&gpu);
        assert(current->suspended && !current->boost_freq.value && phase == 4);
    }
    return 0;
}
'''
    clear = "dev_pm_qos_update_request(&df->boost_freq, 0);"
    assert function.count(clear) == 1
    variants = [function, function.replace(clear, ""),
                function.replace(clear, "").replace("cancel_boost_work(df);", clear + "\n\tcancel_boost_work(df);")]
    with tempfile.TemporaryDirectory(prefix="nabu-gpu-qos-test-") as tmp:
        path = Path(tmp)
        for index, variant in enumerate(variants):
            (path / "test.c").write_text(prefix + variant + suffix)
            subprocess.run(shlex.split(os.environ.get("HOSTCC", "cc")) + [
                "-std=c11", "-Wall", "-Wextra", "-Werror", "-Wno-unused-function",
                str(path / "test.c"), "-o", str(path / "test")], check=True)
            result = subprocess.run([str(path / "test")], capture_output=True)
            assert (result.returncode == 0) == (index == 0), "suspend behavior/mutation gate failed"


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: test-kernel-optimization.py KERNEL_SOURCE FINAL_CONFIG COMPILED_DTB")
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    tree, config_path, dtb_path = map(Path, sys.argv[1:])
    config = dict(line.split("=", 1) for line in config_path.read_text().splitlines() if line.startswith("CONFIG_") and "=" in line)
    check_config(config)
    for name, value in (("NR_CPUS", "512"), ("NUMA", "y"), ("CPU_THERMAL", "n"), ("MODULE_SIG", "n")):
        broken = dict(config, **{"CONFIG_" + name: value})
        try:
            check_config(broken)
        except AssertionError:
            pass
        else:
            raise AssertionError("invalid config accepted: " + name)
    fdt = runpy.run_path(str(Path(__file__).with_name("test-el2-dtb.py")))
    nodes = fdt["read_dtb"](dtb_path.read_bytes())
    fdt["validate"](nodes)
    check_topology(nodes, fdt["cells"])
    broken = copy.deepcopy(nodes)
    broken["/cpus/cpu@700"]["clocks"] = broken["/cpus/cpu@0"]["clocks"]
    try:
        check_topology(broken, fdt["cells"])
    except AssertionError:
        pass
    else:
        raise AssertionError("broken CPU policy accepted")
    test_suspend((tree / "drivers/gpu/drm/msm/msm_gpu_devfreq.c").read_text())
    print("PASS: Nabu final config/8-CPU DT topology; actual MSM suspend C, 10000 mock cycles; 7 negative cases")


if __name__ == "__main__":
    main()
