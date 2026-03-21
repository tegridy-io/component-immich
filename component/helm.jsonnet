// helm template for immich
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.immich;

local values = {
  controllers: {
    main: {
      containers: {
        main: {
          image: {
            tag: params.images.immich.tag,
          },
          [if params.components.database.enabled then 'env']: {
            DB_HOSTNAME: {
              valueFrom: {
                secretKeyRef: {
                  name: 'immich-database-app',
                  key: 'host',
                },
              },
            },
            DB_USERNAME: {
              valueFrom: {
                secretKeyRef: {
                  name: 'immich-database-app',
                  key: 'user',
                },
              },
            },
            DB_PASSWORD: {
              valueFrom: {
                secretKeyRef: {
                  name: 'immich-database-app',
                  key: 'password',
                },
              },
            },
            DB_DATABASE_NAME: {
              valueFrom: {
                secretKeyRef: {
                  name: 'immich-database-app',
                  key: 'dbname',
                },
              },
            },
          },
        },
      },
    },
  },
  immich: {
    configuration: {
      [if params.components.server.ingress.enabled then 'server']: {
        externalDomain: params.components.server.ingress.url,
      },
    } + com.makeMergeable(params.configuration),
    persistence: {
      // Main data store for all photos shared between different components.
      library: {
        // Automatically creating the library volume is not supported by this chart
        // You have to specify an existing PVC to use
        existingClaim: 'immich-library',
      },
    },
  },
  server: {
    enabled: 'true',
    controllers: {
      main: {
        containers: {
          main: {
            image: {
              repository: '%(registry)s/%(repository)s' % params.images.immich,
              tag: params.images.immich.tag,
            },
          },
        },
      },
    },
    ingress: {
      main: {
        enabled: params.components.server.ingress.enabled,
        annotations: params.components.server.ingress.annotations,
        hosts: [ {
          host: params.components.server.ingress.url,
          paths: [ {
            path: '/',
            service: {
              identifier: 'main',
            },
          } ],
        } ],
        [if std.objectHas(params.components.server.ingress.annotations, 'cert-manager.io/cluster-issuer') then 'tls']: [ {
          hosts: [ params.components.server.ingress.url ],
          secretName: 'immich-ingress-tls',
        } ],
      },
    },
  },
  valkey: {
    enabled: params.components.valkey.enabled,
    controllers: {
      main: {
        containers: {
          main: {
            image: {
              repository: '%(registry)s/%(repository)s' % params.images.valkey,
              tag: params.images.valkey.tag,
            },
          },
        },
      },
    },
    persistence: {
      cache: {
        enabled: 'true',
        size: params.components.valkey.storage.size,
        type: 'persistentVolumeClaim',
        accessMode: params.components.valkey.storage.mode,
        storageClass: params.components.valkey.storage.class,
      },
    },
  },
  'machine-learning': {
    enabled: params.components.machineLearning.enabled,
    persistence: {
      cache: {
        enabled: 'true',
        size: params.components.machineLearning.storage.size,
        type: 'persistentVolumeClaim',
        accessMode: params.components.machineLearning.storage.mode,
        storageClass: params.components.machineLearning.storage.class,
      },
    },
  },
};

// Define outputs below
{
  ['%s-values' % inv.parameters._instance]: values,
  ['%s-overrides' % inv.parameters._instance]: params.helmValues,
}
