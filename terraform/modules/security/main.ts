import { Construct } from 'constructs';
import { NetworkingSecgroupV2 } from '../../.gen/providers/openstack/networking-secgroup-v2';
import { NetworkingSecgroupRuleV2 } from '../../.gen/providers/openstack/networking-secgroup-rule-v2';

export type SecurityModuleProps = {
    ENVIRONMENT: string;
}

export class SecurityModule extends Construct {
    private sshSecurityGroup: NetworkingSecgroupV2

    constructor(scope: Construct, id: string, props: SecurityModuleProps) {
        super(scope, id);
        const { ENVIRONMENT } = props;

        this.sshSecurityGroup = new NetworkingSecgroupV2(this, `${ENVIRONMENT}-ssh-security-group`, {
            name: `${ENVIRONMENT}-ssh-security-group`,
            description: 'Allow SSH traffic',
        })

        // allow SSH
        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-ssh-security-ingress-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 22,
            portRangeMin: 22,
            securityGroupId: this.sshSecurityGroup.id,
        });

        // allow ICMP
        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-ssh-security-icmp-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'icmp',
            securityGroupId: this.sshSecurityGroup.id,
        });

        // allow HTTP
        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-ssh-security-http-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 80,
            portRangeMin: 80,
            securityGroupId: this.sshSecurityGroup.id,
        });

        // allow HTTPS
        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-ssh-security-https-rule`, {
            direction: 'ingress',
            ethertype: 'IPv4',
            protocol: 'tcp',
            portRangeMax: 443,
            portRangeMin: 443,
            securityGroupId: this.sshSecurityGroup.id,
        });

        // allow k8s API
        new NetworkingSecgroupRuleV2(this, `${ENVIRONMENT}-ssh-security-k8s-api-rule`, {
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