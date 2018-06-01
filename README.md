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

## How to Provide Parameters to Ansible, or Explanation of Configuration By Ansible, or How to Change The Applied Configuration

Here is how to pass parameters into this CodeBuild instance for Ansible and GitHub.

It is not great practice to write the value of parameters, much less secure parameters like passwords, into source code.
Neither is it great practice to put sensitive values into plaintext or environment variables.
This uses AWS' solution within CodeBuild, namely `env: parameter-store`.

Note that most parameters of a non-sensitive nature here are coming from the `defaults` and `vars` of the roles themselves.

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

Clone private repository in GitHub.

```
  pre_build:
    commands:
      - git clone https://$GITHUB_TOKEN@github.com/MyOrgName/ansible-role-bar.git --branch 0.2.7 bar

```

(This is a work-around because `ansible-galaxy install` lacked the rights to clone).

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

## Specify Ansible Roles

This pipeline calls multiple anisible roles stored in their own GitHub repos.

To work with them, open `buildspec.yml` and view the `pre-build: commands` section.

```
pre-build:
  commands:
...
    - echo "Directly clone all repos for ansible roles here."
    - cd ansible/roles
    - git clone --single-branch --depth 1 https://$GITHUB_TOKEN@github.com/SPSCommerce/ansible-role-sps-common.git --branch 0.2.7 common
    - git clone --single-branch --depth 1 https://$GITHUB_TOKEN@github.com/SPSCommerce/ansible-role-time.git --branch 0.2.2 time
...
```

Notice how several things are specified here:
- Add or remove roles here, then call them in Ansible with the playbook.
- GitHub tags specify version of code by the `--branch` switch.
- The last command token nicknames the role for use by ansible, e.g. `common`.

### Example Ansible Playbook Role Inclusion

Include the roles in the play by their nicknames.
```
  roles:
    - common
    - time
```

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
[cloudformation](https://github.com/SPSCommerce/ami-builder-packer/tree/development/cloudformation)
to tear down or make a new stack. 
