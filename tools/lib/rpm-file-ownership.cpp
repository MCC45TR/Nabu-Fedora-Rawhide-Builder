// Capture and verify RPM file ownership without a Python runtime in the image builder.
#include <cerrno>
#include <charconv>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef NABU_RPM_EXECUTABLE
#define NABU_RPM_EXECUTABLE "/usr/bin/rpm"
#endif

namespace {

using Id = unsigned long;
using Owner = std::pair<Id, Id>;

bool lexists(const std::string &path, struct stat *result = nullptr) {
    struct stat local {};
    if (lstat(path.c_str(), result ? result : &local) == 0) return true;
    if (errno == ENOENT || errno == ENOTDIR) return false;
    throw std::runtime_error("lstat " + path + ": " + std::strerror(errno));
}

Id number(const std::string &text) {
    Id id = 0;
    const auto parsed = std::from_chars(text.data(), text.data() + text.size(), id);
    if (parsed.ec != std::errc() || parsed.ptr != text.data() + text.size())
        throw std::runtime_error("invalid numeric identifier: " + text);
    return id;
}

std::map<std::string, Id> names(const std::string &path) {
    std::ifstream stream(path);
    if (!stream) throw std::runtime_error("cannot read " + path);
    std::map<std::string, Id> result;
    std::string line;
    while (std::getline(stream, line)) {
        const auto first = line.find(':');
        if (first == std::string::npos) continue;
        const auto second = line.find(':', first + 1);
        if (second == std::string::npos) continue;
        const auto third = line.find(':', second + 1);
        if (third == std::string::npos) continue;
        const auto id = line.substr(second + 1, third - second - 1);
        if (!id.empty() && id.find_first_not_of("0123456789") == std::string::npos)
            result[line.substr(0, first)] = number(id);
    }
    return result;
}

std::map<std::string, Owner> capture(const std::string &root, int argc, char **argv,
                                    bool use_dump) {
    const auto uids = names(root + "/etc/passwd");
    const auto gids = names(root + "/etc/group");
    int pipefd[2];
    if (pipe(pipefd) != 0) throw std::runtime_error("pipe failed");
    const pid_t pid = fork();
    if (pid < 0) {
        close(pipefd[0]);
        close(pipefd[1]);
        throw std::runtime_error("fork failed");
    }
    if (pid == 0) {
        close(pipefd[0]);
        if (dup2(pipefd[1], STDOUT_FILENO) < 0) _exit(126);
        close(pipefd[1]);
        if (use_dump)
            execl(NABU_RPM_EXECUTABLE, "rpm", "--root", root.c_str(), "-qa", "--dump",
                  static_cast<char *>(nullptr));
        else
            execl(NABU_RPM_EXECUTABLE, "rpm", "--root", root.c_str(), "-qa", "--qf",
                  "[%{FILENAMES}|%{FILEUSERNAME}|%{FILEGROUPNAME}\n]",
                  static_cast<char *>(nullptr));
        _exit(127);
    }
    close(pipefd[1]);
    FILE *stream = fdopen(pipefd[0], "r");
    if (!stream) {
        close(pipefd[0]);
        int status = 0;
        waitpid(pid, &status, 0);
        throw std::runtime_error("fdopen failed");
    }
    std::map<std::string, Owner> owners;
    std::string error;
    char *line = nullptr;
    size_t capacity = 0;
    while (getline(&line, &capacity, stream) != -1) {
        std::string record(line);
        if (!record.empty() && record.back() == '\n') record.pop_back();
        std::string path, owner, group;
        if (use_dump) {
            // rpm --dump has ten fields after the pathname. Split from the
            // right as the former KDE image builder did, retaining spaces in
            // ordinary pathnames.
            std::string fields[11];
            size_t end = record.size();
            bool valid = true;
            for (int field = 10; field > 0; --field) {
                if (end == 0) { valid = false; break; }
                const auto separator = record.find_last_of(" \t", end - 1);
                if (separator == std::string::npos) { valid = false; break; }
                fields[field] = record.substr(separator + 1, end - separator - 1);
                end = separator;
                while (end > 0 && (record[end - 1] == ' ' || record[end - 1] == '\t')) --end;
            }
            if (!valid) continue;
            path = record.substr(0, end);
            owner = fields[5];
            group = fields[6];
        } else {
            const auto last = record.rfind('|');
            const auto middle = last == std::string::npos ? std::string::npos : record.rfind('|', last - 1);
            if (middle == std::string::npos) continue;
            path = record.substr(0, middle);
            owner = record.substr(middle + 1, last - middle - 1);
            group = record.substr(last + 1);
        }
        if (path.empty() || path.front() != '/') continue;
        if (!lexists(root + path)) continue;
        if (!uids.contains(owner) || !gids.contains(group)) {
            error = "cannot resolve RPM ownership for " + path + ": " + owner + ':' + group;
            break;
        }
        owners[path] = {uids.at(owner), gids.at(group)};
    }
    free(line);
    fclose(stream);
    int status = 0;
    if (waitpid(pid, &status, 0) != pid || !WIFEXITED(status) || WEXITSTATUS(status) != 0)
        throw std::runtime_error("rpm query failed");
    if (!error.empty()) throw std::runtime_error(error);
    for (int index = 4; index < argc; ++index) {
        std::string path(argv[index]);
        if (path.empty() || path.front() != '/')
            throw std::runtime_error("extra path must be absolute: " + path);
        if (lexists(root + path)) owners[path] = {0, 0};
    }
    return owners;
}

void write_capture(const std::string &root, const std::string &output, int argc, char **argv,
                   bool use_dump) {
    const auto owners = capture(root, argc, argv, use_dump);
    std::ofstream stream(output);
    if (!stream) throw std::runtime_error("cannot write " + output);
    for (const auto &[path, owner] : owners)
        stream << path << '|' << owner.first << '|' << owner.second << '\n';
    if (!stream) throw std::runtime_error("cannot finish " + output);
}

void verify(const std::string &root, const std::string &manifest, const std::string &report) {
    std::ifstream input(manifest);
    if (!input) throw std::runtime_error("cannot read " + manifest);
    std::ofstream output(report);
    if (!output) throw std::runtime_error("cannot write " + report);
    std::string details;
    size_t mismatches = 0;
    std::string line;
    while (std::getline(input, line)) {
        const auto last = line.rfind('|');
        const auto middle = last == std::string::npos ? std::string::npos : line.rfind('|', last - 1);
        if (middle == std::string::npos) throw std::runtime_error("invalid ownership manifest record");
        const auto path = line.substr(0, middle);
        if (path.empty() || path.front() != '/') throw std::runtime_error("invalid ownership path");
        const auto uid = number(line.substr(middle + 1, last - middle - 1));
        const auto gid = number(line.substr(last + 1));
        struct stat st {};
        if (!lexists(root + path, &st)) continue;
        if (st.st_uid == uid && st.st_gid == gid) continue;
        ++mismatches;
        details += path + "|expected=" + std::to_string(uid) + ':' + std::to_string(gid) +
                   "|actual=" + std::to_string(st.st_uid) + ':' + std::to_string(st.st_gid) + '\n';
    }
    if (!input.eof()) throw std::runtime_error("cannot finish reading " + manifest);
    output << "mismatches=" << mismatches << '\n' << details;
    if (!output) throw std::runtime_error("cannot finish " + report);
    if (mismatches) throw std::runtime_error(std::to_string(mismatches) +
                                            " RPM-owned paths have incorrect ownership");
}

} // namespace

int main(int argc, char **argv) {
    if (argc < 4 || (std::string(argv[1]) == "verify" && argc != 5) ||
        (std::string(argv[1]) != "capture" && std::string(argv[1]) != "capture-dump" &&
         std::string(argv[1]) != "verify")) {
        std::cerr << "usage: rpm-file-ownership capture[-dump] ROOT OUTPUT [EXTRA_PATH...] | verify ROOT MANIFEST REPORT\n";
        return 2;
    }
    try {
        if (std::string(argv[1]) == "verify") verify(argv[2], argv[3], argv[4]);
        else write_capture(argv[2], argv[3], argc, argv,
                           std::string(argv[1]) == "capture-dump");
    } catch (const std::exception &error) {
        std::cerr << "rpm-file-ownership: " << error.what() << '\n';
        return 1;
    }
}
