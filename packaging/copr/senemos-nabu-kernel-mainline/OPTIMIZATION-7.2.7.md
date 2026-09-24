# Nabu kernel optimization audit — 2026-09-24

## Plan and evidence boundary

1. Audit the applied downstream series, resolved Kconfig, SM8150/Nabu DT,
   runtime-PM and power-profile paths, and previous regression evidence.
2. Implement only source-demonstrable improvements; validate clean patch
   application, negative tests, AArch64 objects, DTB and the optional KVM build.
3. Build a separate COPR candidate, inspect the downloaded signed payload and
   dependency solver, then qualify on hardware before production promotion.

The review is targeted at Nabu's active hardware paths, not a claim that every
line of upstream Linux has been audited. The latest available 7.2.y release
checked on kernel.org is 7.2.7. The base is builder commit `4be07c8`, including
the 156-patch hardware stack and the optional DisplayLink/EL2 packaging.
This candidate adds patches 0159–0161 (159 actual patches in the series).
Release 8 also addresses build warnings: a whitespace-only correction to
legacy patch 0006, GCC for host tools, and isolation of Fedora's GCC-only
generic CFLAGS from Clang descendants. The kernel and EVDI target compiler
remains Clang, with KBUILD_CFLAGS unchanged.

The tablet was last reported powered off after display/driver failures. No
new device logs, power measurements or physical boot results were available
for this audit. The 7.2.7 display/probe/fallback repairs remain prerequisites;
see [REGRESSION-7.2.7.md](REGRESSION-7.2.7.md). No Android partition, calibration,
firmware security state, ESP or boot default is changed by this work.

## Implemented changes

| Change | Verified source evidence | Expected effect and limit |
| --- | --- | --- |
| Eight-CPU build | Final baseline Kconfig has `NR_CPUS=512`; DT describes eight SM8150 CPUs. | Set `NR_CPUS=8`, retaining all cores/hotplug. A `cpumask_t` becomes 8 rather than 64 bytes on arm64. This reduces compile-time-sized masks; it is **not** a measurement of total RAM savings. |
| Single-node memory build | Baseline enables NUMA and automatic NUMA balancing; Nabu describes no multi-node CPU/memory affinity. | Disable NUMA and NUMA balancing, eliminating unnecessary NUMA allocation/scheduler bookkeeping. A single-node system normally does not actively balance between nodes; do not claim a measured reduction in periodic CPU activity. |
| GPU temporary boost cleanup | `msm_devfreq_suspend()` cancels the expiry worker without clearing its PM-QoS minimum request. | Clear that temporary request after worker cancellation. Otherwise a pending request can survive suspend. Active boost algorithm and thermal/max-frequency requests are untouched. This alone is **not** a fix for all CCU faults, display lines or wake failures. |
| Touch build warning | `ATTRIBUTE_GROUPS(nvt_runtime)` emits an unused group-pointer array, while registration uses only the singular group. | Define only `nvt_runtime_group`; preserve managed registration and double-tap-to-wake ABI. No touch firmware timing/threshold changes. |

The GPU change does not access MMIO directly. With A640/GMU, the existing
`suspended` argument makes `a6xx_gmu_set_freq()` update saved state without
powering the GPU back up. The temporary floor is cleared outside `df->lock`,
after cancellation, so QoS notifications are not invoked under that mutex.
The 10,000-cycle extracted-C test uses mocks and checks ordering and state;
it is not a real concurrent-worker, timing or physical suspend experiment.

## Hardware/configuration audit decisions

| Area | Verified state / decision |
| --- | --- |
| CPU topology / EAS | Preserve hardware frequency domains 0/1/2 (4+3+1), capacities 488/1024, power coefficients 232/369/421, shared cache topology, energy model and schedutil. CPU hotplug and all eight PSCI CPUs remain available. |
| Idle / interactive latency | Preserve PSCI CPU idle/domain integration, tickless idle, 250 Hz and full preemption. No `idle=poll`, artificial residency limits, realtime policy or global CPU pinning. |
| Platform profiles | Preserve standard `platform_profile`/frequency-QoS integration. Existing low-power limits and balanced/performance caps remain unchanged; no new frequency or voltage operating points. |
| RAM / compression | Preserve MGLRU, zram/zstd, no zswap double compression and power-efficient workqueues. Keep current THP policy until application/latency measurements justify changing it. |
| CMA / multimedia | Retain 256 MiB CMA and DMA heaps. Reducing reservations without simultaneous camera, video and display tests can create allocation failures. |
| GPU / DSI / panel | Keep patch 0157's SM8150 bonded-PLL correction, firmware-owned display-clock protections and existing recovery diagnostics. Clear only the transient QoS floor; do not disable SMMU or invent bandwidth/OPP values. |
| UFS / root filesystem | Keep the board-specific broken-runtime-PM quirk introduced after captured Samsung UniPro resume timeout and EXT4 abort. System suspend and active-state clock scaling are retained. No speculative gear cap, delay or reset removal. |
| Audio / DSP | Retain four-channel DSP_A, corrected speaker endpoints and frontend shutdown order from patch 0158. No new amplifier gain, supply voltage or calibration writes. Physical four-speaker and thermal tests remain required. |
| Camera / Iris / VA-API | Retain camera EEPROM read-only declarations, bounded front-camera probe recovery and upstream Iris PM error unwind. No speculative buffer-count, reserved-memory or power-collapse reduction. |
| Touch / pen / keyboard | Preserve IRQ/wake/firmware behavior and DT2W opt-in. This release only removes an unused C definition. External keyboard/pen functionality still requires hardware qualification. |
| Sensors / SAR | ADUX1050 data comes through the DSP/SSC integration, not a native ADUX1050 IIO driver in this tree. A source/config test cannot establish changing physical channels or calibrate them; calibration remains untouched. |
| Wi-Fi / Bluetooth / remoteproc | Retain firmware, regulators, reserved memory and standard runtime-PM/wake paths. Do not disable remoteproc or shorten firmware delays to improve a synthetic boot score. |
| USB / DisplayLink | Keep real USB2 hardware topology, UDL and separately built/signed EVDI. No fabricated USB3/DP capability or unconditional daemon/module loading. No dock is available for testing. |
| Security / EL2 | Preserve SELinux, BPF-LSM, module-signing policy, SMMU bypass protection, PSCI SMC, timer PPIs and secure HYP/TZ reservations. Optional KVM variant shares the optimization but cannot create EL2 access if firmware hands off at EL1. |
| Diagnostics | Keep real error/warning paths, pstore and bounded hung-task/watchdog diagnostics. No blanket log suppression or watchdog removal. |

### Additional finding deliberately not mixed into the optimization

`drivers/power/supply/qcom_fg.c` has incomplete resource teardown: its remove
path does not visibly unregister the power-supply notifier, cancel the status
delayed work or release the referenced charger supply. Probe-error unwind also
needs a lifetime audit. This is not evidence of a measured normal-operation
power regression. A separate managed-lifetime correction should test failing
probe, notifier/work races, unbind and charging behavior together. It is not
safe to casually reorder battery-supply teardown while tuning performance.

## Automated gates

- Clean, SHA-256-locked upstream archive plus complete `git am` series.
- Existing DSI extracted-C tests and four-channel audio/DT compatibility test.
- Actual changed GPU/touch AArch64 object compilation and compiled Nabu DTB.
- `test-kernel-optimization.py`: final Kconfig, CPU/NUMA topology and retained
  thermal/security settings; actual suspend function; old behavior, bad order,
  invalid CPU count, NUMA, removed protection and wrong CPU policy are rejected.
- `test-el2-compile.sh`: optional KVM host/VHE/nVHE compilation and identical
  DT/security checks, without claiming hardware EL2 entry.
- Full RPM: Image, signed compressed modules, DTB, boot dependency, depmod,
  essential-driver/vermagic validation and negative payload tests.
- Downloaded RPM signature and module signatures checked separately; AArch64
  solver checked in an empty temporary installroot, not the host or tablet.

## Hardware acceptance before promotion

Use a separate candidate image/boot entry and retain the complete known-good
kernel **and matching modules**, plus Android/recovery. Releases of 7.2.7 share
the same kernel ABI directory: do not mix an older 7.2.7 Image with new modules.
Do not change the production COPR default until this acceptance is recorded.

1. Cold boot: confirm Image/DTB/modules and all eight CPUs, then network,
   touchscreen, panel, DSP, audio and sensors. Record deferred/failed probes.
2. Repeat screen blank/unblank and suspend/resume; capture DSI/GPU, remoteproc,
   UFS and pstore diagnostics with timestamps. Exercise active GPU workload
   before sleep and verify frequency/QoS recovery afterwards.
3. Compare baseline/candidate at equal brightness, refresh rate, Wi-Fi state,
   ambient temperature, battery charge and workload. Measure idle power,
   `MemAvailable`/slab, wake latency, frame pacing and video decode over repeated
   runs. Report raw values and spread, not an invented percentage gain.
4. Validate charging and thermal throttling without bypassing protections;
   test four speakers and simultaneous video/camera memory pressure.
5. Qualify EL2 guests and DisplayLink only with their separate firmware/dock
   prerequisites. Do not conflate their build success with hardware support.

## Primary references

- [kernel.org release metadata](https://www.kernel.org/releases.json)
- [CPU frequency policies](https://docs.kernel.org/admin-guide/pm/cpufreq.html)
- [Energy-aware scheduling](https://docs.kernel.org/scheduler/sched-energy.html)
- [PM QoS interface](https://docs.kernel.org/power/pm_qos_interface.html)
- [Devfreq](https://docs.kernel.org/driver-api/devfreq.html)
- [Zswap architecture](https://docs.kernel.org/admin-guide/mm/zswap.html)

Kernel behavior above was checked against the applied 7.2.7 source, not inferred
solely from documentation. Python added here is build-test code only; production
changes are kernel C and Kconfig. Publication/test results are recorded separately
in the dated workspace report.
