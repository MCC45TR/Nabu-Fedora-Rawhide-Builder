// SPDX-License-Identifier: MIT
// Regenerate the reviewed unified COPR spec without a Python maintainer tool.
#include <algorithm>
#include <array>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <map>
#include <regex>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>
#include <utility>

namespace fs = std::filesystem;

namespace {
using Lines = std::vector<std::string>;
const std::array<std::string, 5> profiles = {
    "gnome-nabu-meta", "gnome-mobile-nabu-meta", "kde-plasma-nabu-meta",
    "kde-plasma-mobile-nabu-meta", "phosh-nabu-meta"};
const std::map<std::string, std::map<int, int>> sourceMap = {
    {"gnome-nabu-meta", {{0, 0}, {1, 1}}},
    {"gnome-mobile-nabu-meta", {{0, 0}, {1, 1}, {2, 13}, {3, 14}, {4, 15},
                                 {5, 16}, {6, 17}, {7, 18}, {8, 19}}},
    {"kde-plasma-nabu-meta", {{0, 4}, {1, 2}, {2, 0}, {3, 3}, {4, 1},
                               {5, 5}, {6, 6}, {7, 7}, {8, 8}}},
    {"kde-plasma-mobile-nabu-meta", {{0, 9}, {1, 10}, {2, 11}, {3, 12},
                                      {4, 2}, {5, 0}, {6, 3}, {7, 1},
                                      {8, 5}, {9, 6}, {10, 7}, {11, 8}}},
    {"phosh-nabu-meta", {{0, 0}}}};

std::string read(const fs::path &path) {
    std::ifstream input(path, std::ios::binary);
    if (!input) throw std::runtime_error("cannot read " + path.string());
    return {std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>()};
}

Lines split(const std::string &value) {
    Lines result;
    std::string line;
    for (char ch : value) {
        if (ch == '\n') {
            result.push_back(line);
            line.clear();
        } else {
            line.push_back(ch);
        }
    }
    if (!line.empty()) result.push_back(line);
    return result;
}

std::string join(const Lines &value, const std::string &separator = "\n") {
    std::string result;
    bool first = true;
    for (const auto &line : value) {
        if (!first) result += separator;
        result += line;
        first = false;
    }
    return result;
}

std::string trimRight(std::string value) {
    while (!value.empty() && std::isspace(static_cast<unsigned char>(value.back())))
        value.pop_back();
    return value;
}

std::string trim(std::string value) {
    value = trimRight(std::move(value));
    const auto first = value.find_first_not_of(" \t\r\n\f\v");
    return first == std::string::npos ? "" : value.substr(first);
}

bool directive(const std::string &line, const std::string &name) {
    return line.rfind(name, 0) == 0 &&
           (line.size() == name.size() || std::isspace(static_cast<unsigned char>(line[name.size()])));
}

bool sectionEnd(const std::string &line) {
    static const std::array<std::string, 10> names = {
        "%prep", "%build", "%install", "%check", "%files", "%post",
        "%preun", "%postun", "%posttrans", "%changelog"};
    return std::any_of(names.begin(), names.end(), [&](const auto &name) { return directive(line, name); });
}

std::string section(const Lines &source, const std::string &heading) {
    Lines body;
    bool found = false;
    for (const auto &line : source) {
        if (!found) {
            found = line == "%" + heading;
        } else if (sectionEnd(line)) {
            break;
        } else {
            body.push_back(line);
        }
    }
    return found ? trimRight(join(body)) : "";
}

std::string description(const Lines &source) {
    Lines body;
    bool found = false;
    for (const auto &line : source) {
        if (!found) {
            found = line == "%description";
        } else if (directive(line, "%prep")) {
            break;
        } else {
            body.push_back(line);
        }
    }
    if (!found) throw std::runtime_error("missing description");
    return trim(join(body));
}

std::string packageHeader(const Lines &source, const std::string &name) {
    Lines result = {"%package -n " + name};
    static const std::regex relevant(R"(^(Summary|Requires|Recommends|Suggests|Conflicts|Provides|Obsoletes):)");
    for (const auto &line : source) {
        if (directive(line, "%description")) break;
        if (std::regex_search(line, relevant)) result.push_back(line);
    }
    return join(result);
}

std::string files(const Lines &source, const std::string &name) {
    Lines body;
    bool found = false;
    for (const auto &line : source) {
        if (!found) {
            found = line == "%files";
        } else if (directive(line, "%post") || directive(line, "%preun") ||
                   directive(line, "%postun") || directive(line, "%posttrans") ||
                   directive(line, "%changelog")) {
            break;
        } else {
            if (name == "kde-plasma-nabu-meta") {
                std::string adjusted = line;
                const std::string duplicate = " l10n/LICENSES/plasma-setup/*";
                const auto offset = adjusted.find(duplicate);
                if (offset != std::string::npos) adjusted.erase(offset, duplicate.size());
                body.push_back(std::move(adjusted));
            } else {
                body.push_back(line);
            }
        }
    }
    if (!found) throw std::runtime_error("missing files section: " + name);
    return trimRight(join(body));
}

bool scriptHeading(const std::string &line) {
    static const std::array<std::string, 6> names = {
        "%pretrans", "%posttrans", "%preun", "%postun", "%pre", "%post"};
    return std::any_of(names.begin(), names.end(), [&](const auto &name) { return directive(line, name); });
}

std::string scriptlets(const Lines &source, const std::string &name) {
    Lines chunks;
    for (std::size_t i = 0; i < source.size(); ++i) {
        if (!scriptHeading(source[i])) continue;
        const auto space = source[i].find_first_of(" \t");
        const std::string command = source[i].substr(0, space);
        std::string options = space == std::string::npos ? "" : source[i].substr(space);
        if (options.find(" -n ") == std::string::npos) options = " -n " + name + options;
        Lines body;
        for (++i; i < source.size() && !scriptHeading(source[i]) &&
                    !directive(source[i], "%files") && !directive(source[i], "%changelog"); ++i)
            body.push_back(source[i]);
        chunks.push_back(command + options + "\n" + trimRight(join(body)));
        if (i < source.size()) --i;
    }
    return join(chunks, "\n\n");
}

std::string remapSources(const std::string &value, const std::string &name) {
    static const std::regex source(R"(%\{SOURCE([0-9]+)\})");
    std::string result;
    std::sregex_iterator it(value.begin(), value.end(), source), end;
    std::size_t cursor = 0;
    for (; it != end; ++it) {
        result += value.substr(cursor, static_cast<std::size_t>(it->position()) - cursor);
        const int old = std::stoi((*it)[1].str());
        result += "%{SOURCE" + std::to_string(sourceMap.at(name).at(old)) + "}";
        cursor = static_cast<std::size_t>(it->position() + it->length());
    }
    return result + value.substr(cursor);
}

std::string generate(const fs::path &here) {
    const fs::path sourceDir = here.parent_path() / "nabu-unified-meta";
    std::map<std::string, Lines> sources;
    std::set<std::string> buildRequires;
    Lines headers;
    for (const auto &name : profiles) {
        auto lines = split(read(sourceDir / (name + ".spec")));
        headers.push_back(packageHeader(lines, name));
        for (const auto &line : lines) {
            if (directive(line, "%description")) break;
            if (line.rfind("BuildRequires:", 0) == 0) buildRequires.insert(line);
        }
        sources.emplace(name, std::move(lines));
    }

    const std::string previous = read(here / "nabu-desktop-metas.spec");
    const auto release = std::regex(R"((?:^|\n)Release:[ \t]*([^\n]+))");
    std::smatch releaseMatch;
    if (!std::regex_search(previous, releaseMatch, release))
        throw std::runtime_error("missing reviewed release in generated spec");
    const auto changelog = previous.find("%changelog\n");
    if (changelog == std::string::npos)
        throw std::runtime_error("missing reviewed changelog in generated spec");

    const auto &gnomeMobile = sources.at("gnome-mobile-nabu-meta");
    const auto &kde = sources.at("kde-plasma-nabu-meta");
    const auto &kdeMobile = sources.at("kde-plasma-mobile-nabu-meta");
    std::string mobileSession = remapSources(section(kdeMobile, "install"), "kde-plasma-mobile-nabu-meta");
    const auto marker = mobileSession.find("install -Dm0755 nabu-audio-orientation");
    if (marker == std::string::npos)
        throw std::runtime_error("mobile session marker missing; review generator before changing package layout");
    mobileSession = trimRight(mobileSession.substr(0, marker));

    Lines out = {
        "%global debug_package %{nil}", "%global legacy_meta_max 9999999999-99", "",
        "Name:           nabu-desktop-metas", "Version:        3.0.0",
        "Release:        " + releaseMatch[1].str(),
        "Summary:        Unified desktop profile family for Xiaomi Pad 5",
        "License:        MIT AND GPL-2.0-or-later AND GPL-3.0-or-later AND BSD-2-Clause AND CC0-1.0",
        "URL:            https://github.com/MCC45TR/Nabu-Fedora-Rawhide-Builder",
        R"(Source0:        nabu-kde-l10n-1.1.0.tar.gz
Source1:        nabu-flashlight-integration-1.0.0.tar.gz
Source2:        nabu-kde-integration-1.4.0.1.tar.gz
Source3:        nabu-kde-widgets-debug-1.0.1.tar.zst
Source4:        95-nabu-plasma-login.preset
Source5:        80-nabu-plasma-login-theme.conf
Source6:        nabu-plasma-login.svg
Source7:        90-nabu-powerdevil.conf
Source8:        90-nabu-compositor-realtime.conf
Source9:        plasma-mobile.desktop
Source10:       20-nabu-mobile-session.conf
Source11:       90-nabu-mobile-login.conf
Source12:       95-nabu-plasma-mobile.preset
Source13:       gnome-mobile-copr.repo
Source14:       nabu-gnome-mobile-sync
Source15:       nabu-gnome-mobile-sync.service
Source16:       nabu-gnome-mobile-sync.timer
Source17:       90-nabu-gnome-mobile-sync.preset
Source18:       test-gnome-mobile-repo-sync.sh
Source19:       20-nabu-mobile-user-mode.conf)"};
    out.insert(out.end(), buildRequires.begin(), buildRequires.end());
    out.insert(out.end(), {"", "%description", "One source package for the five supported Nabu desktop manifests. Existing",
                           "binary RPM names, dependencies, conflicts, integration payloads and update",
                           "semantics are preserved for ordinary DNF upgrades.", ""});
    for (std::size_t i = 0; i < profiles.size(); ++i) {
        const auto &name = profiles[i];
        out.insert(out.end(), {headers[i], "", "%description -n " + name,
                               description(sources.at(name)), ""});
    }
    out.insert(out.end(), {"%prep", "%setup -q -c -T", "mkdir l10n flashlight kde-integration widgets",
                           "tar -xzf %{SOURCE0} -C l10n --strip-components=1",
                           "tar -xzf %{SOURCE1} -C flashlight --strip-components=1",
                           "tar -xzf %{SOURCE2} -C kde-integration --strip-components=1",
                           "tar --zstd -xf %{SOURCE3} -C widgets --strip-components=1",
                           "chmod +x kde-integration/tests/mock-kscreen-doctor", "", "%build",
                           remapSources(section(kde, "build"), "kde-plasma-nabu-meta"), "", "%install",
                           "# Shared GNOME and GNOME Mobile payload\n" +
                               remapSources(section(gnomeMobile, "install"), "gnome-mobile-nabu-meta") +
                               "\n\n# Shared KDE Plasma payload\n" +
                               remapSources(section(kde, "install"), "kde-plasma-nabu-meta") +
                               "\n\n# Plasma Mobile session-only payload\n" + mobileSession,
                           "", "%check"});
    Lines checks;
    for (const auto &name : {"gnome-mobile-nabu-meta", "kde-plasma-nabu-meta", "kde-plasma-mobile-nabu-meta"})
        checks.push_back("# " + std::string(name) + "\n" +
                         remapSources(section(sources.at(name), "check"), name));
    out.insert(out.end(), {join(checks, "\n\n"), ""});
    for (const auto &name : profiles) {
        const auto scripts = scriptlets(sources.at(name), name);
        if (!scripts.empty()) out.insert(out.end(), {scripts, ""});
        out.insert(out.end(), {"%files -n " + name, files(sources.at(name), name), ""});
    }
    // Release and changelog are human-reviewed metadata. Keep them untouched.
    out.push_back(trimRight(previous.substr(changelog)));
    out.push_back("");
    return join(out);
}
} // namespace

int main(int argc, char **argv) {
    const bool checkOnly = argc == 3 && std::string(argv[1]) == "--check";
    if (!(argc == 2 || checkOnly)) {
        std::cerr << "usage: generate-family-spec [--check] SOURCE-DIRECTORY\n";
        return 2;
    }
    try {
        const fs::path here = fs::canonical(argv[checkOnly ? 2 : 1]);
        const std::string result = generate(here);
        if (checkOnly) {
            if (result != read(here / "nabu-desktop-metas.spec"))
                throw std::runtime_error("generated spec is stale; review source changes and regenerate");
            return 0;
        }
        std::ofstream output(here / "nabu-desktop-metas.spec", std::ios::binary | std::ios::trunc);
        if (!output) throw std::runtime_error("cannot write generated spec");
        output << result;
        if (!output) throw std::runtime_error("failed to write generated spec");
    } catch (const std::exception &error) {
        std::cerr << "generate-family-spec: " << error.what() << '\n';
        return 1;
    }
}
