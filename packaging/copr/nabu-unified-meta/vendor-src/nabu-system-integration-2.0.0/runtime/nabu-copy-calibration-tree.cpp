// SPDX-License-Identifier: GPL-2.0-only
// Copy an untrusted Android calibration tree into a trusted volatile tree.

#include <algorithm>
#include <cerrno>
#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <iostream>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

namespace {
constexpr std::size_t kMaxFiles = 512;
constexpr std::size_t kMaxDirectories = 128;
constexpr unsigned int kMaxDepth = 16;
constexpr std::size_t kMaxFileBytes = 1024 * 1024;
constexpr std::size_t kMaxTotalBytes = 16 * 1024 * 1024;

class FileDescriptor {
public:
    explicit FileDescriptor(int fd = -1) : fd_(fd) {}
    ~FileDescriptor() { if (fd_ >= 0) ::close(fd_); }
    FileDescriptor(const FileDescriptor &) = delete;
    FileDescriptor &operator=(const FileDescriptor &) = delete;
    FileDescriptor(FileDescriptor &&other) noexcept : fd_(other.fd_) { other.fd_ = -1; }
    int get() const { return fd_; }
private:
    int fd_;
};

struct Limits {
    std::size_t files = 0;
    std::size_t directories = 0;
    std::size_t totalBytes = 0;
    std::size_t temporaryId = 0;
};

[[noreturn]] void failErrno(const std::string &operation)
{
    throw std::runtime_error(operation + ": " + std::strerror(errno));
}

void validateName(const std::string &name)
{
    if (name.empty() || name == "." || name == ".." || name.find('/') != std::string::npos)
        throw std::runtime_error("unsafe path component: " + name);
}

std::vector<std::string> directoryEntries(int fd)
{
    const int duplicate = ::dup(fd);
    if (duplicate < 0)
        failErrno("dup directory");
    DIR *directory = ::fdopendir(duplicate);
    if (!directory) {
        ::close(duplicate);
        failErrno("fdopendir");
    }
    std::vector<std::string> entries;
    errno = 0;
    while (dirent *entry = ::readdir(directory)) {
        const std::string name(entry->d_name);
        if (name != "." && name != "..")
            entries.push_back(name);
        if (entries.size() > kMaxFiles + kMaxDirectories) {
            ::closedir(directory);
            throw std::runtime_error("source directory exceeds entry limit");
        }
        errno = 0;
    }
    const int saved = errno;
    ::closedir(directory);
    if (saved) {
        errno = saved;
        failErrno("readdir");
    }
    std::sort(entries.begin(), entries.end());
    return entries;
}

void copyRegular(int sourceDirectory, int destinationDirectory,
                 const std::string &sourceName, const std::string &destinationName,
                 Limits &limits)
{
    struct stat before {};
    if (::fstatat(sourceDirectory, sourceName.c_str(), &before, AT_SYMLINK_NOFOLLOW) < 0)
        failErrno("stat source " + sourceName);
    if (!S_ISREG(before.st_mode))
        throw std::runtime_error("source is not a regular file: " + sourceName);
    if (before.st_size < 0 || static_cast<std::size_t>(before.st_size) > kMaxFileBytes)
        throw std::runtime_error("source file exceeds safety limit: " + sourceName);
    if (limits.files >= kMaxFiles)
        throw std::runtime_error("source tree exceeds file limit");

    FileDescriptor source(::openat(sourceDirectory, sourceName.c_str(),
                                   O_RDONLY | O_CLOEXEC | O_NOFOLLOW));
    if (source.get() < 0)
        failErrno("open source " + sourceName);
    struct stat opened {};
    if (::fstat(source.get(), &opened) < 0)
        failErrno("fstat source " + sourceName);
    if (!S_ISREG(opened.st_mode) || opened.st_dev != before.st_dev || opened.st_ino != before.st_ino)
        throw std::runtime_error("source changed while opening: " + sourceName);

    struct stat current {};
    if (::fstatat(destinationDirectory, destinationName.c_str(), &current,
                  AT_SYMLINK_NOFOLLOW) == 0) {
        if (!S_ISREG(current.st_mode))
            throw std::runtime_error("destination collision is not a regular file: " + destinationName);
    } else if (errno != ENOENT) {
        failErrno("stat destination " + destinationName);
    }

    const std::string temporary = ".nabu-copy." + std::to_string(::getpid()) + "." +
                                  std::to_string(++limits.temporaryId);
    FileDescriptor destination(::openat(destinationDirectory, temporary.c_str(),
        O_WRONLY | O_CLOEXEC | O_CREAT | O_EXCL | O_NOFOLLOW, 0640));
    if (destination.get() < 0)
        failErrno("create temporary destination");

    bool installed = false;
    try {
        std::size_t copied = 0;
        char buffer[128 * 1024];
        while (true) {
            const ssize_t amount = ::read(source.get(), buffer, sizeof(buffer));
            if (amount < 0) {
                if (errno == EINTR)
                    continue;
                failErrno("read source " + sourceName);
            }
            if (amount == 0)
                break;
            copied += static_cast<std::size_t>(amount);
            if (copied > kMaxFileBytes || limits.totalBytes + copied > kMaxTotalBytes)
                throw std::runtime_error("source data exceeds safety limits: " + sourceName);
            std::size_t offset = 0;
            while (offset < static_cast<std::size_t>(amount)) {
                const ssize_t written = ::write(destination.get(), buffer + offset,
                                                static_cast<std::size_t>(amount) - offset);
                if (written < 0) {
                    if (errno == EINTR)
                        continue;
                    failErrno("write destination " + destinationName);
                }
                if (written == 0)
                    throw std::runtime_error("zero-length write to " + destinationName);
                offset += static_cast<std::size_t>(written);
            }
        }
        if (::fsync(destination.get()) < 0)
            failErrno("fsync destination " + destinationName);
        if (::renameat(destinationDirectory, temporary.c_str(), destinationDirectory,
                       destinationName.c_str()) < 0)
            failErrno("install destination " + destinationName);
        installed = true;
        ++limits.files;
        limits.totalBytes += copied;
    } catch (...) {
        if (!installed)
            ::unlinkat(destinationDirectory, temporary.c_str(), 0);
        throw;
    }
}

void copyTree(int sourceDirectory, int destinationDirectory, Limits &limits,
              unsigned int depth = 0)
{
    if (depth > kMaxDepth)
        throw std::runtime_error("source tree exceeds depth limit");
    for (const std::string &name : directoryEntries(sourceDirectory)) {
        validateName(name);
        struct stat entry {};
        if (::fstatat(sourceDirectory, name.c_str(), &entry, AT_SYMLINK_NOFOLLOW) < 0)
            failErrno("stat source entry " + name);
        if (S_ISDIR(entry.st_mode)) {
            if (limits.directories >= kMaxDirectories)
                throw std::runtime_error("source tree exceeds directory limit");
            if (::mkdirat(destinationDirectory, name.c_str(), 0750) < 0 && errno != EEXIST)
                failErrno("create destination directory " + name);
            struct stat destinationEntry {};
            if (::fstatat(destinationDirectory, name.c_str(), &destinationEntry,
                          AT_SYMLINK_NOFOLLOW) < 0)
                failErrno("stat destination directory " + name);
            if (!S_ISDIR(destinationEntry.st_mode))
                throw std::runtime_error("destination collision is not a directory: " + name);
            ++limits.directories;
            FileDescriptor sourceChild(::openat(sourceDirectory, name.c_str(),
                O_RDONLY | O_CLOEXEC | O_DIRECTORY | O_NOFOLLOW));
            FileDescriptor destinationChild(::openat(destinationDirectory, name.c_str(),
                O_RDONLY | O_CLOEXEC | O_DIRECTORY | O_NOFOLLOW));
            if (sourceChild.get() < 0 || destinationChild.get() < 0)
                failErrno("open child directory " + name);
            copyTree(sourceChild.get(), destinationChild.get(), limits, depth + 1);
        } else if (S_ISREG(entry.st_mode)) {
            copyRegular(sourceDirectory, destinationDirectory, name, name, limits);
        } else {
            throw std::runtime_error("unsupported source object: " + name);
        }
    }
}

FileDescriptor openDirectory(const std::string &path)
{
    FileDescriptor descriptor(::open(path.c_str(), O_RDONLY | O_CLOEXEC | O_DIRECTORY | O_NOFOLLOW));
    if (descriptor.get() < 0)
        failErrno("open directory " + path);
    return descriptor;
}
} // namespace

int main(int argc, char **argv)
{
    try {
        bool single = false;
        std::vector<std::string> arguments;
        for (int index = 1; index < argc; ++index) {
            if (std::string(argv[index]) == "--single")
                single = true;
            else
                arguments.emplace_back(argv[index]);
        }
        if (arguments.size() != 2)
            throw std::runtime_error("usage: nabu-copy-calibration-tree [--single] SOURCE DESTINATION");
        Limits limits;
        if (!single) {
            FileDescriptor source = openDirectory(arguments[0]);
            FileDescriptor destination = openDirectory(arguments[1]);
            copyTree(source.get(), destination.get(), limits);
        } else {
            const auto sourceSlash = arguments[0].find_last_of('/');
            const auto destinationSlash = arguments[1].find_last_of('/');
            const std::string sourceParent = sourceSlash == std::string::npos ? "." : arguments[0].substr(0, sourceSlash);
            const std::string sourceName = arguments[0].substr(sourceSlash == std::string::npos ? 0 : sourceSlash + 1);
            const std::string destinationParent = destinationSlash == std::string::npos ? "." : arguments[1].substr(0, destinationSlash);
            const std::string destinationName = arguments[1].substr(destinationSlash == std::string::npos ? 0 : destinationSlash + 1);
            validateName(sourceName);
            validateName(destinationName);
            FileDescriptor source = openDirectory(sourceParent);
            FileDescriptor destination = openDirectory(destinationParent);
            copyRegular(source.get(), destination.get(), sourceName, destinationName, limits);
        }
        return 0;
    } catch (const std::exception &error) {
        std::cerr << "nabu-copy-calibration-tree: " << error.what() << '\n';
        return 1;
    }
}
