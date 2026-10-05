#include <glib.h>
#include <gio/gio.h>
#include <stdio.h>
#include <libqmi-glib.h>
#include <libssc/libssc-sensor.h>
#include <libssc/libssc-sensor-proximity.h>

typedef struct {
	GMainLoop *loop;
	int status;
	gboolean as_proximity;
} ProbeContext;

static void
proximity_measurement (SSCSensorProximity *sensor, gboolean near, gpointer user_data)
{
	g_print ("measurement: %s\n", near ? "near" : "far");
	fflush (stdout);
}

static void
sensor_ready (GObject *source, GAsyncResult *result, gpointer user_data)
{
	ProbeContext *ctx = user_data;
	g_autoptr(GError) error = NULL;
	SSCSensor *sensor = ssc_sensor_new_finish (result, &error);
	gchar *name = NULL;
	gchar *vendor = NULL;
	gchar *data_type = NULL;
	guint64 uid_high = 0;
	guint64 uid_low = 0;

	if (sensor == NULL) {
		g_printerr ("not-found: %s\n", error ? error->message : "unknown error");
		ctx->status = 2;
		g_main_loop_quit (ctx->loop);
		return;
	}

	g_object_get (sensor,
		      SSC_SENSOR_NAME, &name,
		      SSC_SENSOR_VENDOR, &vendor,
		      SSC_SENSOR_DATA_TYPE, &data_type,
		      SSC_SENSOR_UID_HIGH, &uid_high,
		      SSC_SENSOR_UID_LOW, &uid_low,
		      NULL);
	g_print ("found: data-type=%s name=%s vendor=%s uid=%" G_GUINT64_FORMAT ":%" G_GUINT64_FORMAT "\n",
		 data_type ? data_type : "", name ? name : "", vendor ? vendor : "",
		 uid_high, uid_low);
	g_free (name);
	g_free (vendor);
	g_free (data_type);
	g_object_unref (sensor);
	ctx->status = 0;
	g_main_loop_quit (ctx->loop);
}

static void
proximity_ready (GObject *source, GAsyncResult *result, gpointer user_data)
{
	ProbeContext *ctx = user_data;
	g_autoptr(GError) error = NULL;
	GObject *object = g_async_initable_new_finish (G_ASYNC_INITABLE (source), result, &error);
	SSCSensorProximity *sensor;

	if (object == NULL) {
		g_printerr ("not-found: %s\n", error ? error->message : "unknown error");
		ctx->status = 2;
		g_main_loop_quit (ctx->loop);
		return;
	}

	sensor = SSC_SENSOR_PROXIMITY (object);
	g_signal_connect (sensor, "measurement", G_CALLBACK (proximity_measurement), ctx);
	if (!ssc_sensor_proximity_open_sync (sensor, NULL, &error)) {
		g_printerr ("open-failed: %s\n", error ? error->message : "unknown error");
		ctx->status = 4;
		g_main_loop_quit (ctx->loop);
		g_object_unref (sensor);
		return;
	}

	g_print ("opened-as-proximity\n");
	ctx->status = 0;
}

static gboolean
probe_timeout (gpointer user_data)
{
	ProbeContext *ctx = user_data;
	g_printerr ("timeout\n");
	ctx->status = 3;
	g_main_loop_quit (ctx->loop);
	return G_SOURCE_REMOVE;
}

int
main (int argc, char **argv)
{
	ProbeContext ctx = { 0 };

	if (argc < 2 || argc > 3 || (argc == 3 && g_strcmp0 (argv[2], "--as-proximity") != 0)) {
		g_printerr ("usage: nabu-ssc-probe DATA_TYPE [--as-proximity]\n");
		return 64;
	}

	ctx.loop = g_main_loop_new (NULL, FALSE);
	ctx.status = 1;
	if (g_getenv ("NABU_SSC_TRACE") != NULL) {
		qmi_utils_set_traces_enabled (TRUE);
		qmi_utils_set_show_personal_info (TRUE);
	}
	ctx.as_proximity = argc == 3;
	if (ctx.as_proximity) {
		g_async_initable_new_async (SSC_TYPE_SENSOR_PROXIMITY,
			G_PRIORITY_DEFAULT, NULL, proximity_ready, &ctx,
			SSC_SENSOR_DATA_TYPE, argv[1], NULL);
	} else {
		ssc_sensor_new (argv[1], NULL, sensor_ready, &ctx);
	}
	g_timeout_add_seconds (15, probe_timeout, &ctx);
	g_main_loop_run (ctx.loop);
	g_main_loop_unref (ctx.loop);
	return ctx.status;
}
