// SPDX-License-Identifier: MIT
// Runtime-only ICC selector. Factory QDCM conversion remains a build/test tool;
// the tablet consumes only checksum-validated, packaged profiles.
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QProcess>
#include <QRegularExpression>
#include <QTextStream>
#include <QtEndian>
#include <cstdlib>

namespace {
[[noreturn]] void fail(const QString &message) {
    QTextStream(stderr) << "senemos-nabu-color-profile: " << message << '\n';
    std::exit(1);
}

quint32 be32(const QByteArray &data, qsizetype offset) {
    if (offset < 0 || offset + 4 > data.size()) fail("ICC structure is truncated");
    return qFromBigEndian<quint32>(reinterpret_cast<const uchar *>(data.constData() + offset));
}

void validateIcc(const QString &path, bool quiet = false) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) fail(QStringLiteral("ICC could not be read: %1").arg(file.errorString()));
    const QByteArray data = file.readAll();
    if (data.size() < 132 || be32(data, 0) != quint32(data.size())) fail("ICC size header is invalid");
    if (data.mid(12, 4) != "mntr" || data.mid(16, 4) != "RGB " || data.mid(20, 4) != "XYZ ")
        fail("ICC is not an RGB/XYZ display profile");
    if (data.mid(36, 4) != "acsp") fail("ICC magic is invalid");
    const quint32 count = be32(data, 128);
    if (count > 4096 || 132ULL + quint64(count) * 12ULL > quint64(data.size())) fail("ICC tag table is invalid");
    QMap<QByteArray, QByteArray> tags;
    for (quint32 i = 0; i < count; ++i) {
        const qsizetype base = 132 + qsizetype(i) * 12;
        const QByteArray name = data.mid(base, 4);
        const quint32 offset = be32(data, base + 4);
        const quint32 size = be32(data, base + 8);
        if (quint64(offset) + quint64(size) > quint64(data.size()))
            fail(QStringLiteral("ICC tag %1 points outside the file").arg(QString::fromLatin1(name)));
        tags.insert(name, data.mid(offset, size));
    }
    const QList<QByteArray> required{"wtpt", "rXYZ", "gXYZ", "bXYZ", "rTRC", "gTRC", "bTRC", "B2A0", "B2A1", "desc"};
    QStringList missing;
    for (const auto &tag : required) if (!tags.contains(tag)) missing << QString::fromLatin1(tag);
    if (!missing.isEmpty()) fail(QStringLiteral("ICC is missing required tags: %1").arg(missing.join(", ")));
    const QList<QByteArray> lutTags{"B2A0", "B2A1"};
    for (const QByteArray &name : lutTags) {
        const QByteArray tag = tags.value(name);
        if (tag.size() < 32 || tag.first(4) != "mBA ") fail(QStringLiteral("ICC %1 is not a LutBToA pipeline").arg(QString::fromLatin1(name)));
        const quint32 clut = be32(tag, 24);
        if (clut == 0 || quint64(clut) + 20 > quint64(tag.size())) fail(QStringLiteral("ICC %1 has no valid CLUT").arg(QString::fromLatin1(name)));
        if (tag.mid(clut, 3) != QByteArray::fromHex("212121")) fail(QStringLiteral("ICC %1 is not a 33x33x33 CLUT").arg(QString::fromLatin1(name)));
    }
    if (!quiet) {
        QTextStream(stdout) << "valid-icc=" << QFileInfo(path).canonicalFilePath() << '\n'
                            << "sha256=" << QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex() << '\n';
    }
}

QByteArray run(const QString &program, const QStringList &arguments, int timeoutMs) {
    QProcess process;
    process.start(program, arguments, QIODevice::ReadOnly);
    if (!process.waitForStarted(timeoutMs) || !process.waitForFinished(timeoutMs)) {
        process.kill(); process.waitForFinished(1000);
        fail(QStringLiteral("command timed out: %1").arg(program));
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0)
        fail(QStringLiteral("command failed: %1").arg(QString::fromUtf8(process.readAllStandardError()).trimmed()));
    return process.readAllStandardOutput();
}

QString internalOutput(const QString &doctor, const QString &requested) {
    QJsonParseError error;
    const auto document = QJsonDocument::fromJson(run(doctor, {"--json"}, 10000), &error);
    if (error.error != QJsonParseError::NoError || !document.isObject()) fail("KScreen output state is not valid JSON");
    QStringList candidates;
    for (const auto &value : document.object().value("outputs").toArray()) {
        const auto output = value.toObject();
        const QString name = output.value("name").toString();
        if (output.value("connected").toBool() && output.value("enabled").toBool() && name.startsWith("DSI-") &&
            (requested.isEmpty() || name == requested)) candidates << name;
    }
    if (requested.isEmpty() && candidates.contains("DSI-1")) candidates = {"DSI-1"};
    if (candidates.size() != 1) fail("exactly one enabled internal DSI output was not found");
    return candidates.constFirst();
}

QString findProfile(const QString &name, const QString &panel, const QString &directory) {
    const QDir dir(QFileInfo(directory).absoluteFilePath());
    const QString pattern = QStringLiteral("xiaomi-nabu-%1-%2.icc").arg(panel.isEmpty() ? "*" : panel, name);
    const QFileInfoList matches = dir.entryInfoList({pattern}, QDir::Files | QDir::Readable, QDir::Name);
    if (matches.size() != 1) fail(QStringLiteral("exactly one matching profile is required; found %1; use --panel").arg(matches.size()));
    const QString path = matches.constFirst().canonicalFilePath();
    if (path.isEmpty() || QFileInfo(path).canonicalPath() != QFileInfo(directory).canonicalFilePath()) fail("profile escaped the trusted profile directory");
    validateIcc(path, true);
    return path;
}

void catalog() {
    QTextStream(stdout)
        << "supported:\n"
        << "  srgb        Android hal_srgb (ModeID 3), SDR, static\n"
        << "  display-p3  Android hal_dci_p3 (ModeID 36), SDR, static\n"
        << "not-converted:\n"
        << "  native      panel primaries are absent from QDCM metadata\n"
        << "  smart_MC    dynamic/content-aware behavior is not an ICC profile\n"
        << "  GM_*/video* Qualcomm PA-v2 operations are not faithfully representable\n"
        << "  hal_hdr     Android HDR metadata/tone mapping is not an SDR ICC profile\n";
}
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QStringList args = app.arguments(); args.removeFirst();
    if (args.isEmpty()) fail("usage: senemos-nabu-color-profile {catalog|validate|apply}");
    const QString command = args.takeFirst();
    if (command == "catalog") { catalog(); return 0; }
    if (command == "validate") {
        if (args.size() != 1) fail("validate requires exactly one ICC path");
        validateIcc(args.constFirst()); return 0;
    }
    if (command != "apply") fail("unsupported command; runtime permits only catalog, validate and explicit apply");
    if (args.isEmpty()) fail("apply requires srgb or display-p3");
    const QString profile = args.takeFirst();
    if (profile != "srgb" && profile != "display-p3") fail("unsupported profile");
    QString panel, directory = "/usr/share/color/icc/senemos/nabu", output;
    bool dryRun = false;
    for (int i = 0; i < args.size(); ++i) {
        if (args[i] == "--panel" && i + 1 < args.size()) panel = args[++i];
        else if (args[i] == "--profile-dir" && i + 1 < args.size()) directory = args[++i];
        else if (args[i] == "--output" && i + 1 < args.size()) output = args[++i];
        else if (args[i] == "--dry-run") dryRun = true;
        else fail(QStringLiteral("unknown option: %1").arg(args[i]));
    }
    if (!panel.isEmpty() && panel != "36-02-0b" && panel != "42-02-0a") fail("unsupported panel revision");
    const QString path = findProfile(profile, panel, directory);
    const QString doctor = qEnvironmentVariable("KSCREEN_DOCTOR", "/usr/bin/kscreen-doctor");
    const QString connector = internalOutput(doctor, output);
    if (dryRun) {
        QTextStream(stdout) << "connector=" << connector << '\n' << "profile=" << path << "\ncolor-profile-source=ICC\n";
        return 0;
    }
    run(doctor, {QStringLiteral("output.%1.iccprofile.%2").arg(connector, path),
                 QStringLiteral("output.%1.colorProfileSource.ICC").arg(connector)}, 15000);
    QTextStream(stdout) << "applied=" << path << '\n' << "connector=" << connector << '\n';
    return 0;
}
