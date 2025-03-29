import { Construct } from 'constructs';
import { NetworkingSecgroupV2 } from '../../.gen/providers/openstack/networking-secgroup-v2';
import { NetworkingSecgroupRuleV2 } from '../../.gen/providers/openstack/networking-secgroup-rule-v2';

export class SecurityModule extends Construct {
    private sshSecurityGroup: NetworkingSecgroupV2

    constructor(scope: Construct, id: string) {
        super(scope, id);

        this.sshSecurityGroup = new NetworkingSecgroupV2(this, `ssh-security-group`, {
            name: `ssh-security-group`,
            description: 'Allow SSH traffic',
        })

        // allow SSH
        new NetworkingSecgroupRuleV2(this, `ssh-security-ingress-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 22,
            portRangeMin: 22,
            securityGroupId: this.sshSecurityGroup.id,
        });

        // allow ICMP
        new NetworkingSecgroupRuleV2(this, `ssh-security-icmp-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'icmp',
            securityGroupId: this.sshSecurityGroup.id,
        });

        // allow HTTP
        new NetworkingSecgroupRuleV2(this, `ssh-security-http-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 80,
            portRangeMin: 80,
            securityGroupId: this.sshSecurityGroup.id,
        });

        // allow HTTPS
        new NetworkingSecgroupRuleV2(this, `ssh-security-https-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 443,
            portRangeMin: 443,
            securityGroupId: this.sshSecurityGroup.id,
        });

        // allow k8s API
        new NetworkingSecgroupRuleV2(this, `ssh-security-k8s-api-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 6443,
            portRangeMin: 6443,
            securityGroupId: this.sshSecurityGroup.id,
        });
        
    }

    public getSshSecurityGroup() {
        return this.sshSecurityGroup
    }
}