#include <pk-backend.h>
#include <pk-backend-spawn.h>

static PkBackendSpawn *spawn;

void
pk_backend_start_job (PkBackend *backend, PkBackendJob *job)
{
	if (pk_backend_spawn_is_busy (spawn))
		pk_backend_job_error_code (job, PK_ERROR_ENUM_LOCK_REQUIRED,
					   "alp helper is already running");
}

void
pk_backend_initialize (GKeyFile *conf, PkBackend *backend)
{
	spawn = pk_backend_spawn_new (conf);
	pk_backend_spawn_set_name (spawn, "alp");
}

void
pk_backend_destroy (PkBackend *backend)
{
	g_clear_object (&spawn);
}

void
pk_backend_cancel (PkBackend *backend, PkBackendJob *job)
{
	pk_backend_spawn_kill (spawn);
}

PkBitfield
pk_backend_get_groups (PkBackend *backend)
{
	return pk_bitfield_from_enums (PK_GROUP_ENUM_OTHER, -1);
}

PkBitfield
pk_backend_get_filters (PkBackend *backend)
{
	return pk_bitfield_from_enums (PK_FILTER_ENUM_INSTALLED, -1);
}

static void
run_search (PkBackendJob *job, const gchar *command, PkBitfield filters, gchar **values)
{
	gchar *filter_text = pk_filter_bitfield_to_string (filters);
	gchar *search_text = g_strjoinv ("&", values);
	pk_backend_spawn_helper (spawn, job, "alpBackend.py", command, filter_text, search_text, NULL);
	g_free (filter_text);
	g_free (search_text);
}

void
pk_backend_refresh_cache (PkBackend *backend, PkBackendJob *job, gboolean force)
{
	pk_backend_spawn_helper (spawn, job, "alpBackend.py", "refresh-cache",
				 pk_backend_bool_to_string (force), NULL);
}

void
pk_backend_get_updates (PkBackend *backend, PkBackendJob *job, PkBitfield filters)
{
	gchar *filter_text = pk_filter_bitfield_to_string (filters);
	pk_backend_spawn_helper (spawn, job, "alpBackend.py", "get-updates", filter_text, NULL);
	g_free (filter_text);
}

void
pk_backend_search_names (PkBackend *backend, PkBackendJob *job, PkBitfield filters, gchar **values)
{
	run_search (job, "search-name", filters, values);
}

void
pk_backend_resolve (PkBackend *backend, PkBackendJob *job, PkBitfield filters, gchar **values)
{
	gchar *filter_text = pk_filter_bitfield_to_string (filters);
	gchar *package_ids = pk_package_ids_to_string (values);
	pk_backend_spawn_helper (spawn, job, "alpBackend.py", "resolve", filter_text, package_ids, NULL);
	g_free (filter_text);
	g_free (package_ids);
}

void
pk_backend_get_details (PkBackend *backend, PkBackendJob *job, gchar **package_ids)
{
	gchar *ids = pk_package_ids_to_string (package_ids);
	pk_backend_spawn_helper (spawn, job, "alpBackend.py", "get-details", ids, NULL);
	g_free (ids);
}

void
pk_backend_depends_on (PkBackend *backend, PkBackendJob *job, PkBitfield filters,
		       gchar **package_ids, gboolean recursive)
{
	gchar *filter_text = pk_filter_bitfield_to_string (filters);
	gchar *ids = pk_package_ids_to_string (package_ids);
	pk_backend_spawn_helper (spawn, job, "alpBackend.py", "depends-on", filter_text, ids,
				 pk_backend_bool_to_string (recursive), NULL);
	g_free (filter_text);
	g_free (ids);
}

void
pk_backend_required_by (PkBackend *backend, PkBackendJob *job, PkBitfield filters,
		gchar **package_ids, gboolean recursive)
{
	gchar *filter_text = pk_filter_bitfield_to_string (filters);
	gchar *ids = pk_package_ids_to_string (package_ids);
	pk_backend_spawn_helper (spawn, job, "alpBackend.py", "required-by", filter_text, ids,
				 pk_backend_bool_to_string (recursive), NULL);
	g_free (filter_text);
	g_free (ids);
}

void
pk_backend_install_packages (PkBackend *backend, PkBackendJob *job, PkBitfield flags, gchar **package_ids)
{
	gchar *ids = pk_package_ids_to_string (package_ids);
	gchar *flag_text = pk_transaction_flag_bitfield_to_string (flags);
	pk_backend_spawn_helper (spawn, job, "alpBackend.py", "install-packages", flag_text, ids, NULL);
	g_free (flag_text);
	g_free (ids);
}

void
pk_backend_remove_packages (PkBackend *backend, PkBackendJob *job, PkBitfield flags,
			    gchar **package_ids, gboolean allow_deps, gboolean autoremove)
{
	gchar *ids = pk_package_ids_to_string (package_ids);
	gchar *flag_text = pk_transaction_flag_bitfield_to_string (flags);
	pk_backend_spawn_helper (spawn, job, "alpBackend.py", "remove-packages", flag_text, ids,
				 pk_backend_bool_to_string (allow_deps),
				 pk_backend_bool_to_string (autoremove), NULL);
	g_free (flag_text);
	g_free (ids);
}

void
pk_backend_update_packages (PkBackend *backend, PkBackendJob *job, PkBitfield flags, gchar **package_ids)
{
	gchar *ids = pk_package_ids_to_string (package_ids);
	gchar *flag_text = pk_transaction_flag_bitfield_to_string (flags);
	pk_backend_spawn_helper (spawn, job, "alpBackend.py", "update-packages", flag_text, ids, NULL);
	g_free (flag_text);
	g_free (ids);
}

const gchar *
pk_backend_get_description (PkBackend *backend)
{
	return "alpbahOS hybrid package manager";
}

const gchar *
pk_backend_get_author (PkBackend *backend)
{
	return "alpbahOS";
}
