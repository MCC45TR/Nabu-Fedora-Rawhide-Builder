// Report RPM-owned translation payloads missing from an installroot.
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <set>
#include <stdexcept>
#include <string>
#include <string_view>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

namespace {

bool starts_with(std::string_view value, std::string_view prefix) {
    return value.starts_with(prefix);
}

bool is_translation(std::string_view path) {
    return starts_with(path, "/usr/share/locale/") ||
           starts_with(path, "/usr/share/qt5/translations/") ||
           starts_with(path, "/usr/share/qt6/translations/");
}

bool lexists(const std::string &path) {
    struct stat st {};
    if (lstat(path.c_str(), &st) == 0) return true;
    if (errno == ENOENT || errno == ENOTDIR) return false;
    throw std::runtime_error("lstat " + path + ": " + std::strerror(errno));
}

std::set<std::pair<std::string, std::string>> rpm_missing(const std::string &root) {
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
        execl("/usr/bin/rpm", "rpm", "--root", root.c_str(), "-qa", "--qf",
              "PKG:%{NAME}\n[%{FILENAMES}\t%{FILEFLAGS:fflags}\n]",
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
    std::set<std::pair<std::string, std::string>> missing;
    char *line = nullptr;
    size_t capacity = 0;
    std::string package;
    std::string error;
    while (getline(&line, &capacity, stream) != -1) {
        std::string record(line);
        if (!record.empty() && record.back() == '\n') record.pop_back();
        if (starts_with(record, "PKG:")) {
            package = record.substr(4);
            continue;
        }
        if (package.empty() || !starts_with(record, "/")) continue;
        const auto separator = record.rfind('\t');
        if (separator == std::string::npos) {
            error = "malformed RPM file record: " + record;
            break;
        }
        const auto path = record.substr(0, separator);
        const auto flags = record.substr(separator + 1);
        // RPM ghost entries deliberately contain no file payload.
        if (flags.find('g') != std::string::npos) continue;
        if (is_translation(path) && !lexists(root + path))
            missing.emplace(package, path);
    }
    free(line);
    fclose(stream);
    int status = 0;
    if (waitpid(pid, &status, 0) != pid || !WIFEXITED(status) || WEXITSTATUS(status) != 0)
        throw std::runtime_error("rpm query failed");
    if (!error.empty()) throw std::runtime_error(error);
    return missing;
}

} // namespace

int main(int argc, char **argv) {
    if (argc != 4) {
        std::cerr << "usage: find-missing-rpm-locales ROOT REPORT PACKAGES\n";
        return 2;
    }
    try {
        const auto missing = rpm_missing(argv[1]);
        std::ofstream report(argv[2]);
        std::ofstream packages(argv[3]);
        if (!report || !packages) throw std::runtime_error("cannot open output files");
        report << "missing=" << missing.size() << '\n';
        std::set<std::string> package_names;
        for (const auto &[package, path] : missing) {
            report << package << '|' << path << '\n';
            package_names.insert(package);
        }
        for (const auto &package : package_names) packages << package << '\n';
        if (!report || !packages) throw std::runtime_error("cannot write output files");
    } catch (const std::exception &error) {
        std::cerr << "find-missing-rpm-locales: " << error.what() << '\n';
        return 1;
    }
}
