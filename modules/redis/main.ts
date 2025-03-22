import { Construct } from "constructs";
import { SecurityModule } from "../security/main";
import { ComputeInstanceV2 } from "../../.gen/providers/openstack/compute-instance-v2";
import { NetworkingFloatingipV2 } from "../../.gen/providers/openstack/networking-floatingip-v2";
import { TerraformOutput } from "cdktf";
import { ComputeKeypairV2 } from "../../.gen/providers/openstack/compute-keypair-v2";
import { NetworkingSecgroupV2 } from "../../.gen/providers/openstack/networking-secgroup-v2";
import { NetworkingSecgroupRuleV2 } from "../../.gen/providers/openstack/networking-secgroup-rule-v2";
import { NetworkingPortV2 } from "../../.gen/providers/openstack/networking-port-v2";
import { DataOpenstackNetworkingNetworkV2 } from "../../.gen/providers/openstack/data-openstack-networking-network-v2";
import { NetworkingFloatingipAssociateV2 } from "../../.gen/providers/openstack/networking-floatingip-associate-v2";
import { Resource } from "../../.gen/providers/null/resource";

export type RedisModuleProps = {
    Security: SecurityModule;
    ENVIRONMENT: string;
    DEFAULT_IMAGE_NAME: string;
    REDIS_FLAVOR_NAME?: string
}

export class RedisModule extends Construct {
    constructor(scope: Construct, id: string, props: RedisModuleProps) {
        super(scope, id);

        const { ENVIRONMENT, DEFAULT_IMAGE_NAME, Security } = props;
        const REDIS_FLAVOR_NAME = props.REDIS_FLAVOR_NAME || "m3.tiny";

        const redisKeyPair = new ComputeKeypairV2(this, `${ENVIRONMENT}-redis-keypair`, {
            name: `${ENVIRONMENT}-redis-keypair`,
        });

        const redisSecurityGroup = new NetworkingSecgroupV2(this, `${ENVIRONMENT}-redis-security-group`, {
            name: `${ENVIRONMENT}-redis-security-group`,
            description: 'Allow Redis traffic',
        });

        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-redis-security-ingress-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 6379,
            portRangeMin: 6379,
            securityGroupId: redisSecurityGroup.id,
        });

        const defaultNet = new DataOpenstackNetworkingNetworkV2(this, `${ENVIRONMENT}-default-net`, {
            name: "auto_allocated_network",
        });

        const redisPort = new NetworkingPortV2(this, `${ENVIRONMENT}-redis-port`, {
            networkId: defaultNet.id,
            securityGroupIds: [redisSecurityGroup.id, Security.getSshSecurityGroup().id],
        });

        const redisInstance = new ComputeInstanceV2(this, `${ENVIRONMENT}`, {
            name: `${ENVIRONMENT}-redis`,
            imageName: DEFAULT_IMAGE_NAME,
            flavorName: REDIS_FLAVOR_NAME,
            keyPair: redisKeyPair.name,
            network: [{ port: redisPort.id }],
            dependsOn: [redisPort],
        });

        const redisInstanceIp = new NetworkingFloatingipV2(this, `${ENVIRONMENT}-redis-ip`, {
            pool: "public",
            portId: redisPort.id,
            dependsOn: [redisPort],
        });

        const redisIpAssociate = new NetworkingFloatingipAssociateV2(this, `${ENVIRONMENT}-redis-ip-associate`, {
            floatingIp: redisInstanceIp.address,
            portId: redisPort.id,
            dependsOn: [redisInstanceIp],
        });

        new Resource(this, `${ENVIRONMENT}-redis-instance-setup`, {
            dependsOn: [redisIpAssociate, redisInstanceIp, redisInstance],
            provisioners: [{
                type: "remote-exec",
                script: `${process.cwd()}/scripts/setup-redis.sh`
            }],
            connection: {
                type: "ssh",
                host: redisInstanceIp.address,
                privateKey: redisKeyPair.privateKey,
                user: "ubuntu"
            }
        })

        new TerraformOutput(this, `${ENVIRONMENT}-redis-connection-string`, {
            value: `redis://default:password@${redisInstanceIp.address}:6379`
        });
    }
}