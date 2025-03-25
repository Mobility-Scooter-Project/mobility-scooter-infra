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
    }

    public getSshSecurityGroup() {
        return this.sshSecurityGroup
    }
}