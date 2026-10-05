#!/usr/bin/bash

check() { return 0; }
depends() { return 0; }
installkernel() { return 0; }

install() {
    local dtb="/usr/lib/modules/${kernel}/dtb/qcom/sm8150-xiaomi-nabu.dtb"
    local firmware
    local -a remoteproc_firmware=(
        /usr/lib/firmware/qcom/sm8150/xiaomi/nabu/slpi_nb.mbn
        /usr/lib/firmware/qcom/sm8150/xiaomi/nabu/cdsp.mbn
        /usr/lib/firmware/qcom/sm8150/xiaomi/nabu/adsp.mbn
        /usr/lib/firmware/qcom/sm8150/xiaomi/nabu/modem.mbn
    )

    [[ -f "$dtb" ]] && inst_simple "$dtb" "/usr/lib/firmware/dtb/sm8150-xiaomi-nabu.dtb"
    for firmware in "${remoteproc_firmware[@]}"; do
        if [[ ! -f "$firmware" ]]; then
            dfatal "Required Nabu remoteproc firmware is missing: $firmware"
            return 1
        fi
        inst_simple "$firmware" "$firmware"
    done
}
