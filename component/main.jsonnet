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
    namespace: params.namespace,
  },
  spec+: {
    accessModes: [ params.components.server.storage.mode ],
  },
  storageClass:: params.components.server.storage.class,
  storage:: params.components.server.storage.size,
};

// Database
local database = {
  apiVersion: 'postgresql.cnpg.io/v1',
  kind: 'Cluster',
  metadata: {
    labels: {
      'app.kubernetes.io/managed-by': 'commodore',
      'app.kubernetes.io/name': 'immich-database',
    },
    name: 'immich-database',
    namespace: params.namespace,
  },
  spec: {
    imageName: '%(registry)s/%(repository)s:%(tag)s' % params.images.vectorchord,
    postgresql: {
      shared_preload_libraries: [ 'vchord.so' ],
    },
    bootstrap: {
      initdb: {
        // TODO: Use managed extensions (pg 18)
        postInitApplicationSQL: [
          // Commands based on: https://immich.app/docs/administration/postgres-standalone/#without-superuser-permission
          'CREATE EXTENSION vchord CASCADE;',
          'CREATE EXTENSION earthdistance CASCADE;',
        ],
      },
    },
  } + com.makeMergeable({
    [key]: params.components.database[key]
    for key in std.objectFields(params.components.database)
    if key != 'enabled'
  }),
};

// Define outputs below
{
  '00_namespace': namespace,
  '01_persistentVolumeClaim': persistentVolumeClaim,
  '02_database': database,
}
