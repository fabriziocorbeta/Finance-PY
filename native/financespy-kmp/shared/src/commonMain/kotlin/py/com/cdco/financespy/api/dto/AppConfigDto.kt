package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

data class AppVersionInfo(
    val versionName: String,
    val versionCode: Int,
    val platform: String = "android"
)

@Serializable
data class AppBuildNumbersDto(
    val android: Int = 1,
    val ios: Int = 1
)

@Serializable
data class AppConfigDto(
    val min_supported_version: String = "0.0.0",
    val latest_version: String = "0.0.0",
    val min_build: AppBuildNumbersDto = AppBuildNumbersDto(),
    val latest_build: AppBuildNumbersDto = AppBuildNumbersDto(),
    val android_store_url: String? = null,
    val ios_store_url: String? = null,
    val direct_apk_url: String? = null,
    val force_update: Boolean = false,
    val release_notes: String? = null,
    val checked_at: String? = null
)

sealed interface UpdateRequirement {
    data object UpToDate : UpdateRequirement

    data class SoftUpdate(
        val latestVersion: String,
        val latestBuild: Int,
        val updateUrl: String?,
        val releaseNotes: String?
    ) : UpdateRequirement

    data class ForceUpdate(
        val minSupportedVersion: String,
        val latestVersion: String,
        val updateUrl: String?,
        val releaseNotes: String?
    ) : UpdateRequirement
}

object AppUpdateEvaluator {
    fun evaluate(
        current: AppVersionInfo,
        config: AppConfigDto,
        dismissedBuild: Int? = null
    ): UpdateRequirement {
        val isIos = current.platform.equals("ios", ignoreCase = true)
        val minBuild = if (isIos) config.min_build.ios else config.min_build.android
        val latestBuild = if (isIos) config.latest_build.ios else config.latest_build.android

        val updateUrl = resolveSafeHttpsUrl(
            if (isIos) {
                listOf(config.ios_store_url)
            } else {
                listOf(config.android_store_url, config.direct_apk_url)
            }
        )

        val belowMin = config.force_update ||
            current.versionCode < minBuild ||
            compareSemVer(current.versionName, config.min_supported_version) < 0

        if (belowMin) {
            return UpdateRequirement.ForceUpdate(
                minSupportedVersion = config.min_supported_version,
                latestVersion = config.latest_version,
                updateUrl = updateUrl,
                releaseNotes = config.release_notes
            )
        }

        val hasNewer = current.versionCode < latestBuild ||
            compareSemVer(current.versionName, config.latest_version) < 0

        if (hasNewer && dismissedBuild != latestBuild) {
            return UpdateRequirement.SoftUpdate(
                latestVersion = config.latest_version,
                latestBuild = latestBuild,
                updateUrl = updateUrl,
                releaseNotes = config.release_notes
            )
        }

        return UpdateRequirement.UpToDate
    }

    internal fun resolveSafeHttpsUrl(candidates: List<String?>): String? {
        return candidates
            .mapNotNull { it?.trim()?.takeIf(String::isNotEmpty) }
            .firstOrNull { it.startsWith("https://", ignoreCase = true) }
    }

    internal fun compareSemVer(a: String, b: String): Int {
        val pa = parseSemVer(a)
        val pb = parseSemVer(b)
        for (i in 0 until 3) {
            if (pa[i] != pb[i]) return pa[i].compareTo(pb[i])
        }
        return 0
    }

    private fun parseSemVer(version: String): IntArray {
        val clean = version.trim().removePrefix("v").substringBefore("-").substringBefore("+")
        val parts = clean.split(".")
        return IntArray(3) { idx -> parts.getOrNull(idx)?.toIntOrNull() ?: 0 }
    }
}
