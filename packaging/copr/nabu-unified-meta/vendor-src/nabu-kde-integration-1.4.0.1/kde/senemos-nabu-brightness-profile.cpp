// SPDX-License-Identifier: MIT
// One-shot profile staging. KWin remains the only runtime brightness owner.
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLockFile>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTextStream>
#include <array>
#include <cmath>

using Curve = std::array<double, 11>;
// Lux thresholds at 0..100% brightness for KWin 6.7's native curve.
// Comfort presets inspired by the Arch profiles, not factory calibration.
static const QMap<QString, Curve> curves{
    {"standard", {-8, 1, 7, 18, 36, 65, 110, 210, 345, 665, 1000}},
    {"bright", {-12, -2, 3, 8, 18, 33, 51, 88, 150, 300, 600}},
    {"dim", {-5, 3, 20, 48, 90, 170, 300, 550, 900, 1600, 4000}},
};

static QJsonDocument readJson(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly) || file.size() > 1024 * 1024) return {};
    QJsonParseError error;
    auto document = QJsonDocument::fromJson(file.readAll(), &error);
    return error.error == QJsonParseError::NoError ? document : QJsonDocument{};
}
static bool writeJson(const QString &path, const QJsonDocument &document) {
    QSaveFile file(path);
    const auto data = document.toJson();
    return file.open(QIODevice::WriteOnly) && file.setPermissions(QFile::ReadOwner | QFile::WriteOwner) &&
        file.write(data) == data.size() && file.commit();
}
static QJsonArray curveJson(const Curve &curve, bool points) {
    QJsonArray result;
    for (qsizetype i = 0; i < qsizetype(curve.size()); i++) {
        if (points) result.append(QJsonArray{curve[i], double(i) / 10});
        else result.append(curve[i]);
    }
    return result;
}
static bool setCurve(QJsonArray &root, const Curve &curve) {
    int matches = 0;
    for (auto entry : root)
        if (entry.toObject().value("name") == "outputs")
            for (auto output : entry.toObject().value("data").toArray())
                if (output.toObject().value("connectorName") == "DSI-1") ++matches;
    if (matches != 1) return false;
    for (qsizetype i = 0; i < root.size(); i++) {
        auto entry = root[i].toObject();
        if (entry.value("name") != "outputs") continue;
        auto outputs = entry.value("data").toArray();
        for (qsizetype j = 0; j < outputs.size(); j++) {
            auto output = outputs[j].toObject();
            if (output.value("connectorName") != "DSI-1") continue;
            const auto old = output.value("autoBrightnessCurve").toArray();
            output["autoBrightnessCurve"] = curveJson(curve, !old.isEmpty() && old[0].isArray());
            outputs[j] = output;
        }
        entry["data"] = outputs;
        root[i] = entry;
    }
    return true;
}
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    const auto args = app.arguments();
    const QString base = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    const QString stateDir = base + "/senemos-nabu";
    const QString stateFile = stateDir + "/brightness-profile.json";
    const QString kwinFile = base + "/kwinoutputconfig.json";
    auto fail = [](const char *message) { QTextStream(stderr) << message << '\n'; return 1; };
    if (args.size() == 2 && args[1] == "--catalog") {
        for (auto it = curves.cbegin(); it != curves.cend(); ++it)
            QTextStream(stdout) << it.key() << '\n';
        return 0;
    }
    if (args.size() == 2 && args[1] == "--status") {
        QTextStream(stdout) << readJson(stateFile).toJson(QJsonDocument::Compact) << '\n';
        return 0;
    }
    if (args.size() == 3 && args[1] == "--stage" && curves.contains(args[2])) {
        if (!QDir().mkpath(stateDir)) return fail("Cannot create profile directory");
        QLockFile lock(stateFile + ".lock");
        if (!lock.tryLock(0)) return fail("A profile operation is already running");
        if (!writeJson(stateFile, QJsonDocument(QJsonObject{{"profile", args[2]}, {"pending", true}})))
            return fail("Cannot stage brightness profile");
        QTextStream(stdout) << "Profile staged for next login; automatic-brightness enablement is unchanged.\n";
        return 0;
    }
    if (args.size() != 2 || args[1] != "--apply-pending")
        return fail("Usage: senemos-nabu-brightness-profile --catalog | --status | --stage standard|bright|dim | --apply-pending");
    if (!QFile::exists(stateFile)) return 0;
    QLockFile lock(stateFile + ".lock");
    if (!lock.tryLock(0)) return fail("A profile operation is already running");
    auto state = readJson(stateFile);
    if (!state.isObject()) return fail("Invalid staged profile; no changes made");
    auto object = state.object();
    if (!object.value("pending").toBool()) return 0;
    const auto profile = object.value("profile").toString();
    if (!curves.contains(profile)) return fail("Unknown profile; no changes made");
    auto *bus = QDBusConnection::sessionBus().interface();
    if (!bus) return fail("No session bus; refusing an unsafe live config edit");
    const auto running = bus->isServiceRegistered("org.kde.KWin");
    if (!running.isValid() || running.value())
        return fail("KWin is running or its state is unknown; profile remains pending until login");
    auto document = readJson(kwinFile);
    if (!document.isArray()) return fail("No valid KWin output configuration yet; profile remains pending");
    auto root = document.array();
    if (!setCurve(root, curves.value(profile)))
        return fail("Expected exactly one DSI-1 output; no changes made");
    if (!writeJson(stateDir + "/kwin-before-brightness-profile.json", document))
        return fail("Cannot back up KWin configuration; no changes made");
    if (!writeJson(kwinFile, QJsonDocument(root))) return fail("Cannot update KWin configuration");
    object["pending"] = false;
    if (!writeJson(stateFile, QJsonDocument(object))) return fail("Profile applied but status could not be saved");
    return 0;
}
