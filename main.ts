import { Construct } from "constructs";
import { App, TerraformStack } from "cdktf";
import { provider } from './.gen/providers/openstack';
import 'dotenv/config';
import { DatabaseModule } from "./modules/database/main";
import { SecurityModule } from "./modules/security/main";
import { NullProvider } from "./.gen/providers/null/provider";


class Main extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);


    const ENVIRONMENT = process.env.ENVIRONMENT!

    const OS_AUTH_URL = process.env.OS_AUTH_URL
    const OS_REGION_NAME = process.env.OS_REGION_NAME
    const OS_APPLICATION_CREDENTIAL_ID = process.env.OS_APPLICATION_CREDENTIAL_ID
    const OS_APPLICATION_CREDENTIAL_SECRET = process.env.OS_APPLICATION_CREDENTIAL_SECRET

    const DEFAULT_IMAGE_NAME = "Featured-Ubuntu24";

    // Providers
    new provider.OpenstackProvider(this, "openstack", {
      authUrl: OS_AUTH_URL,
      region: OS_REGION_NAME,
      applicationCredentialId: OS_APPLICATION_CREDENTIAL_ID,
      applicationCredentialSecret: OS_APPLICATION_CREDENTIAL_SECRET
    })

    new NullProvider(this, "null", {})

    const Security = new SecurityModule(this, `${ENVIRONMENT}-security`, { ENVIRONMENT });
    new DatabaseModule(this, "database", { ENVIRONMENT, DEFAULT_IMAGE_NAME, Security });
  }
}

const app = new App();
new Main(app, "mobility-scooter-web-infra");
app.synth();