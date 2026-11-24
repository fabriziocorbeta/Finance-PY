package py.com.cdco.financespy.api

import py.com.cdco.financespy.api.dto.AppBuildNumbersDto
import py.com.cdco.financespy.api.dto.AppConfigDto
import py.com.cdco.financespy.api.dto.AppUpdateEvaluator
import py.com.cdco.financespy.api.dto.AppVersionInfo
import py.com.cdco.financespy.api.dto.UpdateRequirement
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull

class AppUpdateEvaluatorTest {
    private val baseConfig = AppConfigDto(
        min_supported_version = "0.2.0",
        latest_version = "0.3.0",
        min_build = AppBuildNumbersDto(android = 5, ios = 2),
        latest_build = AppBuildNumbersDto(android = 7, ios = 4),
        android_store_url = "https://play.google.com/store/apps/details?id=py.com.cdco.financespy",
        ios_store_url = "https://apps.apple.com/app/id123456",
        direct_apk_url = "https://finance.cd-co.com.py/downloads/latest.apk",
        force_update = false,
        release_notes = "Mejoras de seguridad"
    )

    @Test
    fun returnsForceUpdateWhenBelowMinimumBuild() {
        val result = AppUpdateEvaluator.evaluate(
            current = AppVersionInfo(versionName = "0.1.9", versionCode = 4, platform = "android"),
            config = baseConfig
        )
        val forced = assertIs<UpdateRequirement.ForceUpdate>(result)
        assertEquals("0.3.0", forced.latestVersion)
        assertEquals(baseConfig.android_store_url, forced.updateUrl)
    }

    @Test
    fun returnsForceUpdateWhenServerFlagIsTrue() {
        val result = AppUpdateEvaluator.evaluate(
            current = AppVersionInfo(versionName = "0.3.0", versionCode = 7, platform = "android"),
            config = baseConfig.copy(force_update = true)
        )
        assertIs<UpdateRequirement.ForceUpdate>(result)
    }

    @Test
    fun returnsSoftUpdateWhenBetweenMinAndLatestAndRespectsDismissal() {
        val soft = AppUpdateEvaluator.evaluate(
            current = AppVersionInfo(versionName = "0.2.0", versionCode = 5, platform = "android"),
            config = baseConfig,
            dismissedBuild = null
        )
        val banner = assertIs<UpdateRequirement.SoftUpdate>(soft)
        assertEquals(7, banner.latestBuild)
        assertEquals("0.3.0", banner.latestVersion)

        val dismissed = AppUpdateEvaluator.evaluate(
            current = AppVersionInfo(versionName = "0.2.0", versionCode = 5, platform = "android"),
            config = baseConfig,
            dismissedBuild = 7
        )
        assertIs<UpdateRequirement.UpToDate>(dismissed)
    }

    @Test
    fun returnsUpToDateWhenAtLatestVersionAndBuild() {
        val result = AppUpdateEvaluator.evaluate(
            current = AppVersionInfo(versionName = "0.3.0", versionCode = 7, platform = "android"),
            config = baseConfig
        )
        assertIs<UpdateRequirement.UpToDate>(result)
    }

    @Test
    fun rejectsNonHttpsUpdateUrls() {
        val result = AppUpdateEvaluator.evaluate(
            current = AppVersionInfo(versionName = "0.1.0", versionCode = 1, platform = "android"),
            config = baseConfig.copy(
                android_store_url = "http://insecure.example.com/app",
                direct_apk_url = "javascript:alert(1)"
            )
        )
        val forced = assertIs<UpdateRequirement.ForceUpdate>(result)
        assertNull(forced.updateUrl)
    }
}
