/**
 * Alpha X Gym — Application Version & Update Management Service
 * Manages minimum required versions, latest releases, force-update triggers,
 * and platform download URLs for both Client and Admin applications.
 */

export interface AppVersionConfig {
  latestVersion: string;
  minimumRequiredVersion: string;
  forceUpdate: boolean;
  releaseNotes: string;
  downloadUrl: string;
  playStoreUrl: string;
  appStoreUrl: string;
  updatedAt: string;
}

class AppVersionService {
  private config: AppVersionConfig = {
    latestVersion: process.env.APP_LATEST_VERSION || '1.0.1',
    minimumRequiredVersion: process.env.APP_MIN_REQUIRED_VERSION || '1.0.0',
    forceUpdate: process.env.APP_FORCE_UPDATE === 'true' || false,
    releaseNotes:
      process.env.APP_RELEASE_NOTES ||
      'Alpha X v1.0.1: Real-time workout assignment synchronization, instant diet plan updates, meal photo upload optimizations, and UI performance enhancements.',
    downloadUrl:
      process.env.APP_DOWNLOAD_URL || 'https://alphaxgym.com/download',
    playStoreUrl:
      process.env.APP_PLAY_STORE_URL ||
      'https://play.google.com/store/apps/details?id=com.alphaxgym.app',
    appStoreUrl:
      process.env.APP_APP_STORE_URL ||
      'https://apps.apple.com/app/id6400000000',
    updatedAt: new Date().toISOString(),
  };

  public getVersionConfig(): AppVersionConfig {
    return { ...this.config };
  }

  public updateVersionConfig(newConfig: Partial<AppVersionConfig>): AppVersionConfig {
    this.config = {
      ...this.config,
      ...newConfig,
      updatedAt: new Date().toISOString(),
    };
    return { ...this.config };
  }
}

export const appVersionService = new AppVersionService();
