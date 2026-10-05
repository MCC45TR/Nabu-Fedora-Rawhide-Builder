// SPDX-License-Identifier: MIT
// On-demand, read-only status. Never loads modules, adds screens or starts services.
#include <evdi_lib.h>
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <string>
#include <vector>

namespace fs = std::filesystem;

static std::optional<std::string> readLine(const fs::path &path) {
    std::ifstream input(path);
    if (!input) return std::nullopt;
    std::string value;
    std::getline(input, value);
    if (input.bad()) return std::nullopt;
    // Sysfs labels are not terminal control sequences; keep output bounded.
    if (value.size() > 160) value.resize(160);
    for (char &c : value)
        if (static_cast<unsigned char>(c) < 32 || c == 127) c = '?';
    return value;
}

int main(int argc, char **argv) {
    fs::path root = "/sys";
    bool requireDock = false;
    for (int i = 1; i < argc; ++i) {
        const std::string arg(argv[i]);
        if (arg == "--help") {
            std::cout << "usage: nabu-displaylink-status [--require-dock] [--sysfs-root PATH]\n"
                         "Read-only snapshot; no root, module loading, daemon or polling.\n"
                         "Dock presence is NOT proof of displayed frames or working hotplug.\n";
            return 0;
        }
        if (arg == "--require-dock") requireDock = true;
        else if (arg == "--sysfs-root" && i + 1 < argc) root = argv[++i];
        else { std::cerr << "Invalid argument\n"; return 2; }
    }
    evdi_lib_version version{};
    evdi_get_lib_version(&version);
    std::cout << "libevdi=" << version.version_major << '.' << version.version_minor
              << '.' << version.version_patchlevel << '\n';
    const auto module = readLine(root / "devices/evdi/version");
    std::cout << "evdi_module_version=" << module.value_or("unavailable") << '\n';
    std::error_code error;
    fs::directory_iterator devices(root / "bus/usb/devices", error);
    if (error) {
        std::cout << "usb_scan=unavailable\ndisplaylink_docks=unknown\n";
        return 2;
    }
    std::vector<std::string> docks;
    const fs::directory_iterator end;
    while (devices != end) {
        const auto path = devices->path();
        const auto vendor = readLine(path / "idVendor");
        // Device directories only, not the child USB interface duplicates.
        if (vendor && *vendor == "17e9" && path.filename().string().find(':') == std::string::npos) {
            const auto product = readLine(path / "idProduct");
            const auto speed = readLine(path / "speed");
            docks.push_back(path.filename().string() + " product=" + product.value_or("unknown") +
                            " usb_mbps=" + speed.value_or("unknown"));
        }
        devices.increment(error);
        if (error) {
            std::cout << "usb_scan=incomplete\ndisplaylink_docks=unknown\n";
            return 2;
        }
    }
    std::sort(docks.begin(), docks.end());
    std::cout << "usb_scan=complete\ndisplaylink_docks=" << docks.size() << '\n';
    for (const auto &dock : docks) std::cout << "dock=" << dock << '\n';
    std::cout << "frames=not_tested hotplug=not_tested suspend=not_tested\n";
    return requireDock && docks.empty() ? 1 : 0;
}
