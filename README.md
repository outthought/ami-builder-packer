## Purpose

This Packer AMI Builder creates a new AMI out of the latest Amazon Linux AMI, and also provides a cloudformation template that leverages AWS CodePipeline to 
orchestrate the entire process.

![Packer AMI Builder Diagram](images/ami-builder-diagram.png)

## Source code structure

```bash
├── ansible
│   ├── playbook.yaml                       <-- Ansible playbook file
│   ├── requirements.yaml                   <-- Ansible Galaxy requirements containing additional Roles to be used (CIS, Cloudwatch Logs)
│   └── roles
│       ├── common                          <-- Upgrades all packages through ``yum``
├── buildspec.yml                           <-- CodeBuild spec 
├── cloudformation                          <-- Cloudformation to create entire pipeline
│   └── pipeline.yaml
├── packer.json                         <-- Packer template for Pipeline
```


## Cloudformation template

Cloudformation will create the following resources as part of the AMI Builder for Packer:

* ``cloudformation/pipeline.yaml``
    + AWS CodeCommit - Git repository
    + AWS CodeBuild - Downloads Packer and run Packer to build AMI 
    + AWS CodePipeline - Orchestrates pipeline and listen for new commits in CodeCommit
    + Amazon SNS Topic - AMI Builds Notification via subscribed email
    + Amazon Cloudwatch Events Rule - Custom Event for AMI Builder that will trigger SNS upon AMI completion


## HOWTO

**Before you start**

* Install [GIT](https://git-scm.com/downloads) if you don't have it
* Make sure AWS CLI is configured properly
* [Configured AWS CLI and Git](http://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-https-unixes.html) to connect to AWS CodeCommit repositories

**Launch the Cloudformation stack**

Region | AMI Builder Launch Template
------------------------------------------------- | ---------------------------------------------------------------------------------
N. Virginia (us-east-1) | [![Launch Stack](images/deploy-to-aws.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=AMI-Builder-Blogpost&templateURL=https://s3-eu-west-1.amazonaws.com/ami-builder-packer/cloudformation/pipeline.yaml)
Ireland (eu-west-1) | [![Launch Stack](images/deploy-to-aws.png)](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/new?stackName=AMI-Builder-Blogpost&templateURL=https://s3-eu-west-1.amazonaws.com/ami-builder-packer/cloudformation/pipeline.yaml)
London (eu-west-2) | [![Launch Stack](images/deploy-to-aws.png)](https://console.aws.amazon.com/cloudformation/home?region=eu-west-2#/stacks/new?stackName=AMI-Builder-Blogpost&templateURL=https://s3-eu-west-1.amazonaws.com/ami-builder-packer/cloudformation/pipeline.yaml)

**To clone the AWS CodeCommit repository (console)**

1.  From the AWS Management Console, open the AWS CloudFormation console.
2.  Choose the AMI-Builder-Blogpost stack, and then choose Output.
3.  Make a note of the Git repository URL.
4.  Use git to clone the repository.
For example: git clone https://git-codecommit.eu-west-1.amazonaws.com/v1/repos/AMI-Builder_repo

**To clone the AWS CodeCommit repository (CLI)**

```bash
# Retrieve CodeCommit repo URL
git_repo=$(aws cloudformation describe-stacks --query 'Stacks[0].Outputs[?OutputKey==`GitRepository`].OutputValue' --output text --stack-name "AMI-Builder-Blogpost")

# Clone repository locally
git clone ${git_repo}
```

Next, we need to copy all files in this repository into the newly cloned Git repository:

* Download [ami-builder-packer ZIP](https://github.com/awslabs/ami-builder-packer/archive/master.zip).
* Extract and copy the contents to the Git repo

Lastly, commit these changes to your AWS CodeCommit repo and watch the AMI being built through the AWS CodePipeline Console:

```bash
git add .
git commit -m "SHIP THIS AMI"
git push origin master
```

![AWS CodePipeline Console - AMI Builder Pipeline](images/ami-builder-pipeline.png)

## Known issues

* ~~Currently, Packer doesn't work with ECS IAM Roles (also used by CodeBuild)~~
    - ~~That's why we build a credentials file that leverages temporary credentials in the ``buildspec``~~
    - ~~When Packer supports this feature, this will no longer be necessary~~
* If Build process fails and within AWS CodeBuild Build logs you find the following line ``Timeout waiting for SSH.``, it means either
    - A) You haven't chosen a VPC Public Subnet, and therefore Packer cannot connect to the instance
    - B) There may have been a connectivity issue between Packer and EC2; retrying the build step within AWS CodePipeline should work just fine 

## Parameters to CloudFormation

Supply the following parameters to the CloudFormation stack.
- BuilderPublicSubnet
- BuilderVPC
- NotificationEmailAddress
- ServiceName

Use a public subnet. This CodeBuild project must be deployed to a VPC with a public subnet. Pass in the ID of a public subnet to the stack.

# Ansible Roles and Variables

## Specify Ansible Roles

To define the Ansible roles applied to the image, do both of the following steps.

1. Add roles to the Ansible playbook in `playbook.yml`.
2. Add source details to the project:
  - If role is in SPSCommerce organization of GitHub:
    + Add repository name and version to `gitrepos` to be cloned by git clone command in `buildspec.yml`
  - If role is from Ansible Galaxy:
    + Add name and version to `requirements.yml` to be installed by packer's call to galaxy.

Specify roles stored in private GitHub repos within the file `buildspec.yml`. By using `git clone` in `pre_build`, CodeBuild can access private GitHub repos.
Public roles are specified in `ansible/requirements.yml` and are fetched within Packer by ansible galaxy (a feat not possible yet for private GitHub).
Any roles obtained by either method, must then be added to the list of roles in `playbook.yml`.

## Ansible Variables

We must pass parameters and passwords to CodeBuild.

We pass in the following parameters using AWS SSM Parameter Store:
- Ansible variables in a map, or dictionary, stored as a string (JSON-object).
- GitHub OAuth token to clone private repos in GitHub.

It is not safe practice to write parameter values into source code, much less secure parameters like passwords.
Neither is it great practice to put sensitive values into plaintext or environment variables.
To try to be secure and modular, we use an AWS' solution within CodeBuild, namely `env: parameter-store`.

Note that most parameters of a non-sensitive nature here are coming from the `defaults` and `vars` of the Ansible roles.

### Secure Parameters in AWS CodeBuild

Open the file `buildspec.yml`. AWS CodeBuild's specification is located here.

Find the `env:` and `parameter-store:` keys. The `parameter-store` section defines secure variables available from SSM Parameter Store.
Define secure variables here to make them available to the container run by CodeBuild.
Each key in capital lettering, is the name of the secure environment variable. This is referencable by `$NAME` in the rest of the document.
Each value should be a key stored in SSM Parameter Store. It is resolved to the value of the key, when referenced by `$NAME`.

### Example env, parameter-store

```
env:
  parameter-store:
    GROUP_VARS: /ansible/vars/ami
```

In this example, `GROUP_VARS` is the name I chose for this variable.

The `/ansible/vars/ami` is the path of a parameter I have put into SSM Parameter Store beforehand.

The value of this parameter, and it must be a plain string, is valid JSON crafted for the purpose to supply our variables to ansible.
For an example of the structure and how to put the parameter into SSM Parameter Store, see below.

### Referencing Parameters

#### Example CodeBuild Parameter-Store group_vars

To use the parameters in your CodeBuild container, reference their value with a `$`.
```
  pre_build:
    commands:
      - echo "$GROUP_VARS" > ansible/group_vars/all
```

In this case, put the entire JSON string into a file path ansible is expecting, `ansible/group_vars/all`, for variable values.

#### Example CodeBuild Parameter-Store GitHub OAuth Token

Clone private repository in GitHub. Add the roles you with to reference and a tag or commit sha to `ansible/repos/gitrepos`.
```
ansible-role-sps-common 0.2.7
ansible-role-cloud-init 0.0.13
ansible-role-authconfig 1.3.5
ansible-role-sudo 0.0.7
ansible-role-snmpd 0.2.5
ansible-role-deploy-monitor 1.2.2
```

The roles listed here will be cloned in the container using a GitHub OAuth Token.

### How to Put Parameter Containing Ansible Vars

Create a JSON string with your structured ansible group vars.
```
$ cat vars.json
{
    "bind_user": "u4325",
    "bind_value": "Aw3som3Sawz",
    "sudoers": [
        {"userorgroup": "support"},
        {"userorgroup": "devops"}
}
```
(These are ficticious values).
Create the structure with your ansible variables and their appropriate values.

Put them into SSM Parameter Store with the AWS cli.

`aws ssm put-parameter --name '/ansible/vars/ami' --type SecureString --value (echo (cat vars.json))`

## Configuration Outside of Ansible Roles

Ansible roles supply the bulk of the applied configuration. Outside of Ansible, Packer executes additional configuration in provisioners.
It is important to note that configuration of the images can occur here, too.

To work with Packer's provisioners, open `packer.json`.
In the `provisioners` section notice that there are shell provisioners and a call to ansible provisioners.

There is a shell provisioner that enables `ansible-local` to work by installing ansible on the instance. 

There is another shell provisioner that cleans up the instance before capture as an image.

Bear in mind when working with images, that configuration is specified here as well as in Ansible.

## CloudFormation and Terraform

If you wish to re-deploy, or teardown and make again this entire CodePipeline, it is easy.
Use the CloudFormation file `pipeline.yaml` in
[cloudformation](https://github.com/SPSCommerce/ami-builder/tree/development/cloudformation)
to tear down or make a new stack. 

You may have to remove the s3 bucket manually, prior to `terraform destroy`.
```
set bucket (terraform output | awk '/bucket/ {print $3}'); and echo $bucket
aws s3 rb s3://$bucket --force
```
