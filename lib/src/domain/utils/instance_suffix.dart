String instanceSuffix(String? instanceName) =>
    instanceName == null || instanceName.isEmpty ? '' : '_$instanceName';
