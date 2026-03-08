// main template for immich
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.immich;

// Namespace
local namespace = kube.Namespace(params.namespace) {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-wave': '-10',
    } + com.makeMergeable(std.get(params.namespaceMetadata, 'annotations', {})),
    labels+: {
      'app.kubernetes.io/name': params.namespace,
      'app.kubernetes.io/managed-by': 'commodore',
    } + com.makeMergeable(std.get(params.namespaceMetadata, 'labels', {})),
  },
};

// Storage
local persistentVolumeClaim = kube.PersistentVolumeClaim('immich-library') {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-wave': '-10',
    },
    labels+: {
      'app.kubernetes.io/managed-by': 'commodore',
      'app.kubernetes.io/name': 'immich-library',
    },
  },
  spec+: {
    accessModes: [ params.components.server.storage.mode ],
  },
  storageClass:: params.components.server.storage.class,
  storage:: params.components.server.storage.size,
};

// Define outputs below
{
  '00_namespace': namespace,
  '01_persistentVolumeClaim': persistentVolumeClaim,
}
