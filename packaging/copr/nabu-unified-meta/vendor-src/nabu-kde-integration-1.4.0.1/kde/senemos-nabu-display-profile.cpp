// SPDX-License-Identifier: MIT
#include <QCoreApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QProcess>
#include <QRegularExpression>
#include <QTextStream>
#include <cstdlib>

namespace {
struct Profile { double scale; const char *logicalSize; };

[[noreturn]] void fail(const QString &message) {
    QTextStream(stderr) << "senemos-nabu-display-profile: " << message << '\n';
    std::exit(1);
}

QByteArray run(const QString &program, const QStringList &arguments, int timeoutMs) {
    QProcess process;
    process.setProcessChannelMode(QProcess::SeparateChannels);
    process.start(program, arguments, QIODevice::ReadOnly);
    if (!process.waitForStarted(timeoutMs) || !process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(1000);
        fail(QStringLiteral("KScreen command timed out: %1").arg(program));
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        fail(QStringLiteral("KScreen command failed: %1").arg(
            QString::fromUtf8(process.readAllStandardError()).trimmed()));
    }
    return process.readAllStandardOutput();
}

QJsonArray textOutputs(const QByteArray &raw) {
    QString plain = QString::fromUtf8(raw);
    plain.remove(QRegularExpression(QStringLiteral("\\x1b\\[[0-9;]*m")));
    const QRegularExpression header(QStringLiteral("Output:\\s+\\d+\\s+(\\S+)"));
    const QRegularExpression mode(QStringLiteral("\\b\\d+:(\\d+)x(\\d+)@[0-9.]+\\*"));
    const QStringList blocks = plain.split(QRegularExpression(QStringLiteral("(?=Output:\\s+\\d+\\s+)")), Qt::SkipEmptyParts);
    QJsonArray outputs;
    for (const QString &block : blocks) {
        const auto h = header.match(block);
        const auto m = mode.match(block);
        if (!h.hasMatch() || !m.hasMatch()) continue;
        QJsonObject size{{"width", m.captured(1).toInt()}, {"height", m.captured(2).toInt()}};
        QJsonObject entry{{"id", "current"}, {"size", size}};
        outputs.append(QJsonObject{
            {"name", h.captured(1)},
            {"connected", QRegularExpression(QStringLiteral("(?m)^\\s*connected\\s*$")).match(block).hasMatch()},
            {"enabled", QRegularExpression(QStringLiteral("(?m)^\\s*enabled\\s*$")).match(block).hasMatch()},
            {"currentModeId", "current"},
            {"modes", QJsonArray{entry}},
        });
    }
    if (outputs.isEmpty()) fail("KScreen text output did not contain a current display mode");
    return outputs;
}

QJsonArray loadOutputs(const QString &doctor) {
    QProcess process;
    process.start(doctor, {"--json"}, QIODevice::ReadOnly);
    if (process.waitForStarted(10000) && process.waitForFinished(10000) &&
        process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0) {
        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(process.readAllStandardOutput(), &error);
        if (error.error == QJsonParseError::NoError && document.isObject())
            return document.object().value("outputs").toArray();
    } else {
        process.kill();
        process.waitForFinished(1000);
    }
    return textOutputs(run(doctor, {"-o"}, 10000));
}

QJsonObject internalPanel(const QJsonArray &outputs, const QString &requested) {
    QList<QJsonObject> candidates;
    for (const auto &value : outputs) {
        const auto output = value.toObject();
        if (output.value("connected").toBool() && output.value("enabled").toBool())
            candidates.append(output);
    }
    if (!requested.isEmpty()) {
        candidates.removeIf([&](const QJsonObject &o) { return o.value("name").toString() != requested; });
    } else {
        QList<QJsonObject> dsi1;
        for (const auto &o : candidates) if (o.value("name").toString() == "DSI-1") dsi1.append(o);
        if (!dsi1.isEmpty()) candidates = dsi1;
        else candidates.removeIf([](const QJsonObject &o) { return !o.value("name").toString().startsWith("DSI-"); });
    }
    if (candidates.size() != 1) fail("exactly one enabled internal DSI panel was not found");
    const auto output = candidates.constFirst();
    if (!output.value("name").toString().startsWith("DSI-"))
        fail("refusing to alter a connector that is not an internal DSI panel");
    const QString current = output.value("currentModeId").toVariant().toString();
    QJsonObject selected;
    for (const auto &value : output.value("modes").toArray()) {
        const auto mode = value.toObject();
        if (mode.value("id").toVariant().toString() == current) { selected = mode; break; }
    }
    if (selected.isEmpty()) fail("the internal panel current mode could not be identified");
    const auto size = selected.value("size").toObject();
    const int width = size.value("width").toInt();
    const int height = size.value("height").toInt();
    if (!((width == 1600 && height == 2560) || (width == 2560 && height == 1600)))
        fail(QStringLiteral("refusing to alter a non-native panel mode (%1x%2)").arg(width).arg(height));
    return output;
}
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QStringList args = app.arguments();
    args.removeFirst();
    bool dryRun = false;
    QString requested;
    QString profileName;
    for (int i = 0; i < args.size(); ++i) {
        if (args[i] == "--dry-run") dryRun = true;
        else if (args[i] == "--output" && i + 1 < args.size()) requested = args[++i];
        else if (args[i].startsWith("--")) fail(QStringLiteral("unknown option: %1").arg(args[i]));
        else if (profileName.isEmpty()) profileName = args[i];
        else fail("too many arguments");
    }
    if (profileName == "fullhd") profileName = "fhd";
    if (profileName == "2k") profileName = "native";
    const QMap<QString, Profile> profiles{
        {"native", {1.0, "2560x1600 landscape / 1600x2560 portrait"}},
        {"fhd", {4.0 / 3.0, "1920x1200 landscape / 1200x1920 portrait"}},
        {"hd", {2.0, "1280x800 landscape / 800x1280 portrait"}},
    };
    if (!profiles.contains(profileName))
        fail("usage: senemos-nabu-display-profile {native|fhd|hd} [--output DSI-1] [--dry-run]");
    const QString doctor = qEnvironmentVariable("KSCREEN_DOCTOR", "/usr/bin/kscreen-doctor");
    const QString connector = internalPanel(loadOutputs(doctor), requested).value("name").toString();
    const auto profile = profiles.value(profileName);
    const QString scale = QString::number(profile.scale, 'g', 12);
    if (dryRun) {
        QTextStream(stdout) << "profile=" << profileName << " connector=" << connector << " scale=" << scale << '\n'
                            << "logical-size=" << profile.logicalSize << '\n'
                            << "physical-mode=2560x1600 (unchanged)\n";
        return 0;
    }
    run(doctor, {QStringLiteral("output.%1.scale.%2").arg(connector, scale)}, 15000);
    QTextStream(stdout) << "Applied " << profileName << ": " << profile.logicalSize
                        << "; physical panel timing remains native 2560x1600.\n";
    return 0;
}
