// SPDX-License-Identifier: MIT
#include <QCoreApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSet>
#include <QTextStream>
#include <QThread>
#include <algorithm>
#include <atomic>
#include <csignal>
#include <stdexcept>

namespace {
constexpr auto kSink = "nabu_screen_speakers";
constexpr auto kPlayback = "playback.nabu_screen_speakers";
const QStringList kPositions{"FL", "FR", "RL", "RR"};
const QMap<int, QStringList> kRotationMap{
    {1, {"FL", "FR", "RL", "RR"}}, {2, {"RL", "FL", "RR", "FR"}},
    {4, {"RR", "RL", "FR", "FL"}}, {8, {"FR", "RR", "FL", "RL"}},
};
std::atomic_bool running{true};

void stopHandler(int) { running.store(false); }
void log(const QString &message) { QTextStream(stdout) << "nabu-audio-orientation: " << message << '\n'; }

double envDouble(const char *name, double fallback, double minimum) {
    bool ok = false; const double value = qEnvironmentVariable(name).toDouble(&ok);
    return qMax(minimum, ok ? value : fallback);
}

QByteArray commandOutput(const QString &program, const QStringList &args, int timeout = 5000, bool required = true) {
    QProcess process;
    process.start(program, args, QIODevice::ReadOnly);
    if (!process.waitForStarted(timeout) || !process.waitForFinished(timeout)) {
        process.kill(); process.waitForFinished(1000);
        if (required) throw std::runtime_error((program + " timed out").toStdString());
        return {};
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        if (required) throw std::runtime_error((program + ": " + QString::fromUtf8(process.readAllStandardError()).trimmed()).toStdString());
        return {};
    }
    return process.readAllStandardOutput();
}

bool runCommand(const QString &program, const QStringList &args, int timeout = 5000) {
    try { commandOutput(program, args, timeout); return true; }
    catch (const std::exception &error) { log(error.what()); return false; }
}

QJsonArray pipewireObjects() {
    try {
        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(commandOutput("pw-dump", {}), &error);
        if (error.error == QJsonParseError::NoError && document.isArray()) return document.array();
    } catch (...) {}
    return {};
}

QJsonObject props(const QJsonObject &item) { return item.value("info").toObject().value("props").toObject(); }
QList<QJsonObject> nodes(const QJsonArray &objects) {
    QList<QJsonObject> result;
    for (const auto &value : objects) {
        const auto item = value.toObject();
        if (item.value("type").toString() == "PipeWire:Interface:Node") result.append(item);
    }
    return result;
}

QString discoverTarget(const QJsonArray &objects) {
    const QString configured = qEnvironmentVariable("NABU_AUDIO_TARGET").trimmed();
    QList<QPair<int, QString>> candidates;
    for (const auto &node : nodes(objects)) {
        const auto p = props(node); const QString name = p.value("node.name").toString();
        if (!configured.isEmpty()) { if (name == configured) return name; continue; }
        if (p.value("media.class").toString() != "Audio/Sink" || p.value("device.api").toString() != "alsa" || !name.startsWith("alsa_output.")) continue;
        if (p.value("audio.channels").toVariant().toInt() != 4) continue;
        const QString positions = p.value("audio.position").toVariant().toString();
        bool complete = true; for (const auto &position : kPositions) complete &= positions.contains(position);
        if (!complete) continue;
        const QString description = (p.value("node.description").toString() + ' ' + p.value("device.profile.description").toString() + ' ' + p.value("node.nick").toString()).toLower();
        candidates.append({description.contains("speaker") ? 1 : 0, name});
    }
    std::sort(candidates.begin(), candidates.end(), [](const auto &a, const auto &b) { return a > b; });
    return candidates.isEmpty() ? QString{} : candidates.constFirst().second;
}

int kwinRotation() {
    QString path = qEnvironmentVariable("NABU_KWIN_OUTPUT_CONFIG");
    if (path.isEmpty()) path = QDir::homePath() + "/.config/kwinoutputconfig.json";
    QFile file(path); if (!file.open(QIODevice::ReadOnly)) return 0;
    QJsonParseError error; const auto document = QJsonDocument::fromJson(file.readAll(), &error);
    if (error.error != QJsonParseError::NoError || !document.isArray()) return 0;
    QJsonArray outputs;
    for (const auto &value : document.array()) {
        const auto section = value.toObject();
        if (section.value("name").toString() == "outputs") {
            for (const auto &output : section.value("data").toArray()) outputs.append(output);
        }
    }
    QJsonObject selected;
    for (const auto &value : outputs) if (value.toObject().value("connectorName").toString() == "DSI-1") { selected = value.toObject(); break; }
    if (selected.isEmpty() && !outputs.isEmpty()) selected = outputs.first().toObject();
    const QMap<QString, int> transforms{{"Normal", 1}, {"Rotated90", 2}, {"Rotated180", 4}, {"Rotated270", 8}};
    return transforms.value(selected.value("transform").toString(), 0);
}

int screenRotation() {
    bool ok = false; const QString override = qEnvironmentVariable("NABU_ROTATION_OVERRIDE").trimmed();
    if (!override.isEmpty()) { const int value = override.toInt(&ok); return ok ? value : 0; }
    const QString rotationFile = qEnvironmentVariable("NABU_ROTATION_FILE").trimmed();
    if (!rotationFile.isEmpty()) { QFile file(rotationFile); if (file.open(QIODevice::ReadOnly)) { const int value = QString::fromLatin1(file.readAll()).trimmed().toInt(&ok); return ok ? value : 0; } return 0; }
    const int persisted = kwinRotation(); if (kRotationMap.contains(persisted)) return persisted;
    try {
        QJsonParseError error; const auto document = QJsonDocument::fromJson(commandOutput("kscreen-doctor", {"--json"}), &error);
        if (error.error != QJsonParseError::NoError || !document.isObject()) return 0;
        QList<QJsonObject> candidates;
        for (const auto &value : document.object().value("outputs").toArray()) {
            const auto output = value.toObject(); if (output.value("connected").toBool() && output.value("enabled").toBool()) candidates.append(output);
        }
        QList<QJsonObject> internal; for (const auto &output : candidates) if (output.value("type").toInt() == 7) internal.append(output);
        if (!internal.isEmpty()) candidates = internal;
        if (candidates.isEmpty()) return 0;
        std::sort(candidates.begin(), candidates.end(), [](const auto &a, const auto &b) { return a.value("priority").toInt(9999) < b.value("priority").toInt(9999); });
        return candidates.constFirst().value("rotation").toVariant().toInt();
    } catch (...) { return 0; }
}

int findNode(const QJsonArray &objects, const QString &name) {
    for (const auto &node : nodes(objects)) if (props(node).value("node.name").toString() == name) return node.value("id").toInt(-1);
    return -1;
}

QMap<QString, int> portMap(const QJsonArray &objects, int nodeId, const QString &direction) {
    QMap<QString, int> result;
    for (const auto &value : objects) {
        const auto item = value.toObject(); if (item.value("type").toString() != "PipeWire:Interface:Port") continue;
        const auto p = props(item);
        if (p.value("node.id").toVariant().toInt() != nodeId || p.value("port.direction").toString() != direction) continue;
        const QString channel = p.value("audio.channel").toString(); if (kPositions.contains(channel)) result[channel] = item.value("id").toInt();
    }
    return result;
}

QSet<QString> asSet(const QStringList &values) { return QSet<QString>(values.cbegin(), values.cend()); }

struct Link { int id; int output; int input; };
QList<Link> outputLinks(const QJsonArray &objects, int playbackId) {
    QList<Link> result;
    for (const auto &value : objects) {
        const auto item = value.toObject(); if (item.value("type").toString() != "PipeWire:Interface:Link") continue;
        const auto info = item.value("info").toObject();
        if (info.value("output-node-id").toInt(-1) == playbackId)
            result.append({item.value("id").toInt(), info.value("output-port-id").toInt(), info.value("input-port-id").toInt()});
    }
    return result;
}

void repairVolume() {
    try {
        QJsonParseError error; const auto document = QJsonDocument::fromJson(commandOutput("pactl", {"--format=json", "list", "sinks"}), &error);
        if (error.error != QJsonParseError::NoError || !document.isArray()) return;
        QJsonObject sink; for (const auto &value : document.array()) if (value.toObject().value("name").toString() == kSink) { sink = value.toObject(); break; }
        if (sink.isEmpty()) return;
        const auto volume = sink.value("volume").toObject(); int peak = 0; bool anyZero = false;
        for (const auto &name : {"front-left", "front-right", "rear-left", "rear-right"}) {
            const int value = volume.value(name).toObject().value("value").toInt(); peak = qMax(peak, value); anyZero |= value <= 0;
        }
        if (peak <= 0 || !anyZero) return;
        const QString percent = QString::number(peak * 100.0 / 65536.0, 'f', 6) + '%';
        runCommand("pactl", {"set-sink-volume", kSink, percent, percent, percent, percent});
        log("initialized restored volume for all four speaker channels");
    } catch (...) {}
}

int waitForFilter(QProcess &process) {
    for (int i = 0; i < 50 && running.load(); ++i) {
        if (process.state() == QProcess::NotRunning) throw std::runtime_error("speaker filter exited");
        const auto objects = pipewireObjects(); const int sink = findNode(objects, kSink); const int playback = findNode(objects, kPlayback);
        if (sink >= 0 && playback >= 0 && asSet(portMap(objects, playback, "out").keys()) == asSet(kPositions)) return sink;
        QThread::msleep(100);
    }
    throw std::runtime_error("persistent stereo-to-four-channel filter did not appear");
}

void selectSink(int sinkId) {
    repairVolume(); runCommand("wpctl", {"set-default", QString::number(sinkId)});
    for (const auto &node : nodes(pipewireObjects())) {
        const auto p = props(node); if (p.value("media.class").toString() != "Stream/Output/Audio" || p.value("node.name").toString().contains(kSink)) continue;
        runCommand("wpctl", {"move", QString::number(node.value("id").toInt()), QString::number(sinkId)});
    }
}

QString pairKey(int a, int b) { return QString::number(a) + ':' + QString::number(b); }
void reconcile(const QString &target, int rotation) {
    const auto objects = pipewireObjects(); const int playback = findNode(objects, kPlayback); const int targetId = findNode(objects, target);
    if (playback < 0 || targetId < 0) throw std::runtime_error("four-channel filter or target sink node is unavailable");
    const auto outputs = portMap(objects, playback, "out"); const auto inputs = portMap(objects, targetId, "in");
    if (outputs.size() != 4 || inputs.size() != 4) throw std::runtime_error("four-channel filter or hardware ports are incomplete");
    QSet<QString> desired;
    for (int i = 0; i < 4; ++i) desired.insert(pairKey(outputs.value(kPositions[i]), inputs.value(kRotationMap.value(rotation)[i])));
    QSet<QString> existing; for (const auto &link : outputLinks(objects, playback)) existing.insert(pairKey(link.output, link.input));
    for (const auto &key : desired - existing) { const auto parts = key.split(':'); if (!runCommand("pw-link", {"-L", "-P", "-w", parts[0], parts[1]})) throw std::runtime_error("could not create PipeWire link"); }
    for (const auto &link : outputLinks(pipewireObjects(), playback)) if (!desired.contains(pairKey(link.output, link.input)))
        if (!runCommand("pw-link", {"-d", QString::number(link.id)})) throw std::runtime_error("could not remove obsolete PipeWire link");
    QSet<QString> verified; for (const auto &link : outputLinks(pipewireObjects(), playback)) verified.insert(pairKey(link.output, link.input));
    if (verified != desired) throw std::runtime_error("link verification failed");
    log(QStringLiteral("rotation=%1 target=%2 mapping=%3 four-channel=true stable-sink=true").arg(rotation).arg(target, kRotationMap.value(rotation).join(',')));
}

int selfTest() {
    QSet<QString> seen;
    for (auto it = kRotationMap.cbegin(); it != kRotationMap.cend(); ++it) {
        if (it.value().size() != 4 || asSet(it.value()) != asSet(kPositions)) return 1;
        QTextStream(stdout) << "rotation=" << it.key() << " mapping=" << it.value().join(',') << '\n';
        seen.insert(it.value().join(','));
    }
    return seen.size() == 4 ? 0 : 1;
}
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    if (app.arguments().contains("--self-test")) return selfTest();
    std::signal(SIGINT, stopHandler); std::signal(SIGTERM, stopHandler);
    const double poll = envDouble("NABU_AUDIO_POLL_SECONDS", 1.0, 0.25);
    const double settle = envDouble("NABU_AUDIO_ROTATION_SETTLE_SECONDS", 1.5, 0.0);
    const double refresh = envDouble("NABU_AUDIO_TARGET_REFRESH_SECONDS", 60.0, 5.0);
    QString target, activeTarget; int candidate = 0, active = 0; qint64 candidateSince = 0, nextRefresh = 0;
    QElapsedTimer clock; clock.start(); QProcess filter;
    const QString config = qEnvironmentVariable("NABU_AUDIO_FILTER_CONFIG", "/usr/share/senemos-nabu/nabu-speaker-filter-chain.conf");
    while (running.load()) {
        if (filter.state() == QProcess::NotRunning) {
            filter.start("pipewire", {"-c", config});
            try { if (!filter.waitForStarted(5000)) throw std::runtime_error("speaker filter could not start"); const int sink = waitForFilter(filter); selectSink(sink); log(QStringLiteral("persistent sink ready sink-id=%1").arg(sink)); }
            catch (const std::exception &error) { log(error.what()); filter.kill(); filter.waitForFinished(1000); QThread::msleep(2000); continue; }
            active = 0; activeTarget.clear(); nextRefresh = 0;
        }
        const qint64 now = clock.elapsed(); const int rotation = screenRotation();
        if (kRotationMap.contains(rotation) && rotation != candidate) { candidate = rotation; candidateSince = now; }
        if (now >= nextRefresh) { target = discoverTarget(pipewireObjects()); nextRefresh = now + qint64(refresh * 1000); }
        const bool ready = kRotationMap.contains(candidate) && (active == 0 || now - candidateSince >= qint64(settle * 1000));
        if (!target.isEmpty() && ready && (target != activeTarget || candidate != active)) {
            try { reconcile(target, candidate); active = candidate; activeTarget = target; }
            catch (const std::exception &error) { log(error.what()); QThread::msleep(1000); continue; }
        }
        QThread::msleep(unsigned(poll * 1000));
    }
    filter.terminate(); if (!filter.waitForFinished(3000)) { filter.kill(); filter.waitForFinished(3000); }
    return 0;
}
