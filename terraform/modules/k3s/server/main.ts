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
    DEFAULT_IMAGE_NAME: string;
    K3S_HEAD_FLAVOR_NAME?: string
}

export class K3sServerModule extends Construct {
    constructor(scope: Construct, id: string, props: k3sServerModuleProps) {
        super(scope, id);

        const { DEFAULT_IMAGE_NAME, Security } = props;
        const K3S_HEAD_FLAVOR_NAME = props.K3S_HEAD_FLAVOR_NAME || "m3.quad";

        const k3sHeadKeyPair = new ComputeKeypairV2(this, `k3s-head-keypair`, {
            name: `k3s-head-keypair`,
        });

        // Jetstream recommends using the auto_allocated_network
        const defaultNet = new DataOpenstackNetworkingNetworkV2(this, `default-network`, {
            name: "auto_allocated_network",
        });

        /**
         * The order and dependencies of the resources are important.
         * Openstack will not allow the the provisioners to run if the
         * resources are not created in the correct order and assigned
         * in this exact way.
         */
        const k3sHeadPort = new NetworkingPortV2(this, `k3s-head-port`, {
            networkId: defaultNet.id,
            securityGroupIds: [Security.getSshSecurityGroup().id],
        });

        const k3sHeadInstance = new ComputeInstanceV2(this, `k3s-head`, {
            name: `k3s-head`,
            imageName: DEFAULT_IMAGE_NAME,
            flavorName: K3S_HEAD_FLAVOR_NAME,
            keyPair: k3sHeadKeyPair.name,
            network: [{ port: k3sHeadPort.id }],
            dependsOn: [k3sHeadPort],
        });

        const k3sHeadInstanceIp = new NetworkingFloatingipV2(this, `k3s-head-ip`, {
            pool: "public",
            portId: k3sHeadPort.id,
            dependsOn: [k3sHeadPort],
        });

        const k3sHeadIpAssociate = new NetworkingFloatingipAssociateV2(this, `k3s-head-ip-associate`, {
            floatingIp: k3sHeadInstanceIp.address,
            portId: k3sHeadPort.id,
            dependsOn: [k3sHeadInstanceIp],
        });

        new Resource(this, `k3s-head-instance-setup`, {
            dependsOn: [k3sHeadIpAssociate, k3sHeadInstanceIp, k3sHeadInstance],
            provisioners: [{
            type: "file",
            source: `${process.cwd()}/../scripts/setup-k3s-head.sh`,
            destination: "/tmp/setup-k3s-head.sh",
            },
            {
            type: "file",
            source: `${process.cwd()}/../cluster`,
            destination: "/tmp/cluster",
            },
            {
            type: "remote-exec",
            inline: [
                "chmod +x /tmp/setup-k3s-head.sh",
                `sudo FLOATING_IP=${k3sHeadInstanceIp.address} INSTANCE_ID=${k3sHeadInstance.id} /tmp/setup-k3s-head.sh`,
            ]
            },
            // This copies the cluster config to the local machine for developer use
            {
            type: "local-exec",
            command: [
                "mkdir -p /tmp/ssh",
                `echo "${k3sHeadKeyPair.privateKey}" > /tmp/ssh/k3s_private_key`,
                "chmod 600 /tmp/ssh/k3s_private_key",
                `ssh -o StrictHostKeyChecking=no -i /tmp/ssh/k3s_private_key ubuntu@${k3sHeadInstanceIp.address} "sudo cat ~/local-cluster.config" > ${process.cwd()}/../cluster.config`,
                `sed -i "s/127.0.0.1/${k3sHeadInstanceIp.address}/g" ${process.cwd()}/../cluster.config`
            ].join(" && ")
            }
            ],
            // for some reason, using password authentication does not work
            connection: {
            type: "ssh",
            host: k3sHeadInstanceIp.address,
            privateKey: k3sHeadKeyPair.privateKey,
            user: "ubuntu",
            },
        })
    }
}