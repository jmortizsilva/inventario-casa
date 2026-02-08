// metro.config.js
const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Deshabilitar node externals que causan problemas con OneDrive
config.resolver.resolveRequest = (context, moduleName, platform) => {
  // Evitar el problema con node:sea y otros módulos node: en OneDrive
  if (moduleName.startsWith('node:')) {
    return {
      type: 'empty',
    };
  }
  return context.resolveRequest(context, moduleName, platform);
};

module.exports = config;
