const { getDefaultConfig } = require("expo/metro-config");
const { withNativeWind } = require("nativewind/metro");
const path = require("path");

/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);

// Disable Watchman for file watching.
config.resolver.useWatchman = false;

// Configure transformer options.
config.transformer = {
  ...config.transformer,
  getTransformOptions: async () => ({
    transform: {
      experimentalImportSupport: false,
      inlineRequires: true,
    },
  }),
};

// Configure resolver with web platform mocking and module deduplication
config.resolver = {
  ...config.resolver,
  useWatchman: false,
  resolveRequest: (context, moduleName, platform) => {
    // Mock native-only modules on web
    if (platform === "web") {
      const nativeOnlyModules = [
        "react-native-pager-view",
        "reanimated-tab-view",
        "@bottom-tabs/react-navigation",
      ];

      if (nativeOnlyModules.some((mod) => moduleName.includes(mod))) {
        return {
          type: "empty",
        };
      }
    }

    // Deduplicate @react-navigation/native: expo-router bundles a nested
    // copy whose LinkingContext is a different object from the top-level
    // copy used by @react-navigation/native-stack. Force every import to
    // resolve from the project root so a single LinkingContext is shared.
    if (moduleName === "@react-navigation/native") {
      return context.resolveRequest(
        { ...context, originModulePath: path.resolve(__dirname, "index.ts") },
        moduleName,
        platform
      );
    }

    // Fallback to default resolution
    return context.resolveRequest(context, moduleName, platform);
  },
};

// Integrate NativeWind with the Metro configuration.
module.exports = withNativeWind(config, { input: "./global.css" });
