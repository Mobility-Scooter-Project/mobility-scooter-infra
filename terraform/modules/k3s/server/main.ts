import { Construct } from "constructs";
import { SecurityModule } from "../../security/main";
import { ComputeInstanceV2 } from "../../../.gen/providers/openstack/compute-instance-v2";
import { NetworkingFloatingipV2 } from "../../../.gen/providers/openstack/networking-floatingip-v2";
import { TerraformOutput } from "cdktf";
import { NetworkingSecgroupV2 } from "../../../.gen/providers/openstack/networking-secgroup-v2";
import { NetworkingSecgroupRuleV2 } from "../../../.gen/providers/openstack/networking-secgroup-rule-v2";
import { NetworkingPortV2 } from "../../../.gen/providers/openstack/networking-port-v2";
import { DataOpenstackNetworkingNetworkV2 } from "../../../.gen/providers/openstack/data-openstack-networking-network-v2";
import { NetworkingFloatingipAssociateV2 } from "../../../.gen/providers/openstack/networking-floatingip-associate-v2";
import { Resource } from "../../../.gen/providers/null/resource";
import { ComputeKeypairV2 } from "../../../.gen/providers/openstack/compute-keypair-v2";

export type k3sServerModuleProps = {
    Security: SecurityModule;
    ENVIRONMENT: string;
    DEFAULT_IMAGE_NAME: string;
    K3S_SERVER_FLAVOR_NAME?: string
}

export class K3sServerModule extends Construct {
    constructor(scope: Construct, id: string, props: k3sServerModuleProps) {
        super(scope, id);

        const { ENVIRONMENT, DEFAULT_IMAGE_NAME, Security } = props;
        const k3sServer_FLAVOR_NAME = props.K3S_SERVER_FLAVOR_NAME || "m3.small";

        const k3sServerKeyPair = new ComputeKeypairV2(this, `${ENVIRONMENT}-k3s-server-keypair`, {
            name: `${ENVIRONMENT}-k3s-server-keypair`,
        });

        const k3sServerSecurityGroup = new NetworkingSecgroupV2(this, `${ENVIRONMENT}-k3s-server-security-group`, {
            name: `${ENVIRONMENT}-k3s-server-security-group`,
            description: 'Allow PostgreSQL traffic',
        });

        // ArgoCD API
        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-k3s-server-security-ingress-rule-3`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 80,
            portRangeMin: 80,
            securityGroupId: k3sServerSecurityGroup.id,
        });

        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-k3s-server-security-ingress-rule-4`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 443,
            portRangeMin: 443,
            securityGroupId: k3sServerSecurityGroup.id,
        });

        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-k3s-server-security-ingress-rule-5`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 6443,
            portRangeMin: 6443,
            securityGroupId: k3sServerSecurityGroup.id,
        });

        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-k3s-server-security-ingress-rule-6`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 10250,
            portRangeMin: 10250,
            securityGroupId: k3sServerSecurityGroup.id,
        });

        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-k3s-server-security-ingress-rule-7`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 8080,
            portRangeMin: 8080,
            securityGroupId: k3sServerSecurityGroup.id,
        });

        const defaultNet = new DataOpenstackNetworkingNetworkV2(this, `${ENVIRONMENT}-default-net`, {
            name: "auto_allocated_network",
        });

        const k3sServerPort = new NetworkingPortV2(this, `${ENVIRONMENT}-k3s-server-port`, {
            networkId: defaultNet.id,
            securityGroupIds: [k3sServerSecurityGroup.id, Security.getSshSecurityGroup().id],
        });

        const k3sServerInstance = new ComputeInstanceV2(this, `${ENVIRONMENT}`, {
            name: `${ENVIRONMENT}-k3s-server`,
            imageName: DEFAULT_IMAGE_NAME,
            flavorName: k3sServer_FLAVOR_NAME,
            keyPair: k3sServerKeyPair.name,
            network: [{ port: k3sServerPort.id }],
            dependsOn: [k3sServerPort],
        });

        const k3sServerInstanceIp = new NetworkingFloatingipV2(this, `${ENVIRONMENT}-k3s-server-ip`, {
            pool: "public",
            portId: k3sServerPort.id,
            dependsOn: [k3sServerPort],
        });

        const k3sServerIpAssociate = new NetworkingFloatingipAssociateV2(this, `${ENVIRONMENT}-k3s-server-ip-associate`, {
            floatingIp: k3sServerInstanceIp.address,
            portId: k3sServerPort.id,
            dependsOn: [k3sServerInstanceIp],
        });

        new Resource(this, `${ENVIRONMENT}-k3s-server-instance-setup`, {
            dependsOn: [k3sServerIpAssociate, k3sServerInstanceIp, k3sServerInstance],
            provisioners: [{
                type: "file",
                source: `${process.cwd()}/../scripts/setup-k3s-server.sh`,
                destination: "/tmp/setup-k3s-server.sh",
            },
            {
                type: "file",
                source: `${process.cwd()}/../cluster`,
                destination: "/tmp/kustomize",
            },
            {
                type: "remote-exec",
                inline: [
                    `export FLOATING_IP=${k3sServerInstanceIp.address}`,
                    "chmod +x /tmp/setup-k3s-server.sh",
                    "/tmp/setup-k3s-server.sh",
                ]
            }],
            connection: {
                type: "ssh",
                host: k3sServerInstanceIp.address,
                privateKey: k3sServerKeyPair.privateKey,
                user: "ubuntu",
            }
        })

        new TerraformOutput(this, `${ENVIRONMENT}-k3s-server-ip-output`, {
            value: k3sServerInstanceIp.address,
        });
    }
}