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

export type DatabaseModuleProps = {
    Security: SecurityModule;
    ENVIRONMENT: string;
    DEFAULT_IMAGE_NAME: string;
    DATABASE_FLAVOR_NAME?: string
}

export class DatabaseModule extends Construct {
    constructor(scope: Construct, id: string, props: DatabaseModuleProps) {
        super(scope, id);

        const { ENVIRONMENT, DEFAULT_IMAGE_NAME, Security } = props;
        const DATABASE_FLAVOR_NAME = props.DATABASE_FLAVOR_NAME || "m3.tiny";

        const pgKeyPair = new ComputeKeypairV2(this, `${ENVIRONMENT}-pg-keypair`, {
            name: `${ENVIRONMENT}-pg-keypair`,
        });

        const pgSecurityGroup = new NetworkingSecgroupV2(this, `${ENVIRONMENT}-pg-security-group`, {
            name: `${ENVIRONMENT}-pg-security-group`,
            description: 'Allow PostgreSQL traffic',
        });

        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-pg-security-ingress-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 5432,
            portRangeMin: 5432,
            securityGroupId: pgSecurityGroup.id,
        });


        const defaultNet = new DataOpenstackNetworkingNetworkV2(this, `${ENVIRONMENT}-default-net`, {
            name: "auto_allocated_network",
        });

        const pgPort = new NetworkingPortV2(this, `${ENVIRONMENT}-pg-port`, {
            networkId: defaultNet.id,
            securityGroupIds: [pgSecurityGroup.id, Security.getSshSecurityGroup().id],
        });

       const pgInstance = new ComputeInstanceV2(this, `${ENVIRONMENT}`, {
            name: `${ENVIRONMENT}-pg`,
            imageName: DEFAULT_IMAGE_NAME,
            flavorName: DATABASE_FLAVOR_NAME,
            keyPair: pgKeyPair.name,
            network: [{ port: pgPort.id }],
            dependsOn: [pgPort],
        });

        const pgInstanceIp = new NetworkingFloatingipV2(this, `${ENVIRONMENT}-pg-ip`, {
            pool: "public",
            portId: pgPort.id,
            dependsOn: [pgPort],
        });

        const pgIpAssociate = new NetworkingFloatingipAssociateV2(this, `${ENVIRONMENT}-pg-ip-associate`, {
            floatingIp: pgInstanceIp.address,
            portId: pgPort.id,
            dependsOn: [pgInstanceIp],
        });

        new Resource(this, `${ENVIRONMENT}-pg-instance-setup`, {
            dependsOn: [pgIpAssociate, pgInstanceIp, pgInstance],
            provisioners: [{
                type: "remote-exec",
                script: `${process.cwd()}/scripts/setup-postgres.sh`
            }],
            connection: {
                type: "ssh",
                host: pgInstanceIp.address,
                privateKey: pgKeyPair.privateKey,
                user: "ubuntu"
            }
        })

        new TerraformOutput(this, `${ENVIRONMENT}-postgres-connection-string`, {
            value: `postgres://postgres:postgres@${pgInstanceIp.address}`,
        });
    }
}