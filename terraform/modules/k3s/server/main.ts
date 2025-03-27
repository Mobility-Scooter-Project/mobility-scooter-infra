import { Construct } from "constructs";
import { SecurityModule } from "../../security/main";
import { ComputeInstanceV2 } from "../../../.gen/providers/openstack/compute-instance-v2";
import { NetworkingFloatingipV2 } from "../../../.gen/providers/openstack/networking-floatingip-v2";
import { TerraformOutput } from "cdktf";
import { NetworkingSecgroupV2 } from "../../../.gen/providers/openstack/networking-secgroup-v2";
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

        const { DEFAULT_IMAGE_NAME, Security } = props;
        const k3sServer_FLAVOR_NAME = props.K3S_SERVER_FLAVOR_NAME || "m3.small";

        const k3sServerKeyPair = new ComputeKeypairV2(this, `k3s-server-keypair`, {
            name: `k3s-server-keypair`,
        });

        const k3sServerSecurityGroup = new NetworkingSecgroupV2(this, `k3s-server-security-group`, {
            name: `-k3s-server-security-group`,
            description: 'Allow PostgreSQL traffic',
        });

        const defaultNet = new DataOpenstackNetworkingNetworkV2(this, `default-net`, {
            name: "auto_allocated_network",
        });

        const k3sServerPort = new NetworkingPortV2(this, `k3s-server-port`, {
            networkId: defaultNet.id,
            securityGroupIds: [k3sServerSecurityGroup.id, Security.getSshSecurityGroup().id],
        });

        const k3sServerInstance = new ComputeInstanceV2(this, `k3s-server`, {
            name: `k3s-server`,
            imageName: DEFAULT_IMAGE_NAME,
            flavorName: k3sServer_FLAVOR_NAME,
            keyPair: k3sServerKeyPair.name,
            network: [{ port: k3sServerPort.id }],
            dependsOn: [k3sServerPort],
        });

        const k3sServerInstanceIp = new NetworkingFloatingipV2(this, `k3s-server-ip`, {
            pool: "public",
            portId: k3sServerPort.id,
            dependsOn: [k3sServerPort],
        });

        const k3sServerIpAssociate = new NetworkingFloatingipAssociateV2(this, `k3s-server-ip-associate`, {
            floatingIp: k3sServerInstanceIp.address,
            portId: k3sServerPort.id,
            dependsOn: [k3sServerInstanceIp],
        });

        new Resource(this, `k3s-server-instance-setup`, {
            dependsOn: [k3sServerIpAssociate, k3sServerInstanceIp, k3sServerInstance],
            provisioners: [{
            type: "file",
            source: `${process.cwd()}/../scripts/setup-k3s-server.sh`,
            destination: "/tmp/setup-k3s-server.sh",
            },
            {
            type: "file",
            source: `${process.cwd()}/../cluster`,
            destination: "/tmp/cluster",
            },
            {
            type: "remote-exec",
            inline: [
                "chmod +x /tmp/setup-k3s-server.sh",
                `sudo FLOATING_IP=${k3sServerInstanceIp.address} /tmp/setup-k3s-server.sh`,
            ]
            },
            {
            type: "local-exec",
            command: [
                "mkdir -p /tmp/ssh",
                `echo "${k3sServerKeyPair.privateKey}" > /tmp/ssh/k3s_private_key`,
                "chmod 600 /tmp/ssh/k3s_private_key",
                `ssh -o StrictHostKeyChecking=no -i /tmp/ssh/k3s_private_key ubuntu@${k3sServerInstanceIp.address} "sudo cat ~/local-cluster.config" > ${process.cwd()}/../cluster.config`,
                `sed -i "s/127.0.0.1/${k3sServerInstanceIp.address}/g" ${process.cwd()}/../cluster.config`
            ].join(" && ")
            }
            ],
            connection: {
            type: "ssh",
            host: k3sServerInstanceIp.address,
            privateKey: k3sServerKeyPair.privateKey,
            user: "ubuntu",
            },
        })
        new TerraformOutput(this, `k3s-server-ip-output`, {
            value: k3sServerInstanceIp.address,
        });
    }
}