# Examine a VPC and create cloudformation stack from its parameters.

variable NotificationEmailAddress {}
variable ServiceName {}

# If the target vpc is from a cloudformation stack, then we may use the aws_cloudformation_stack data source.

# variable cfn_vpc {}

# data "aws_cloudformation_stack" "cfn" {
#   name = "${var.cfn_vpc}"
# }

# resource "aws_cloudformation_stack" "amibu" {
#   name         = "amibu"
#   template_url = "./cloudformation/pipeline.json"

#   parameters {
#     BuilderPublicSubnet      = "${element(split(",", data.aws_cloudformation_stack.cfn.outputs.internalSubnets), 0)}"
#     BuilderVPC               = ["${data.aws_cloudformation_stack.cfn.outputs.SPSLinuxSG}"]
#     NotificationEmailAddress = "${var.NotificationEmailAddress}"
#     ServiceName              = "${var.ServiceName}"
#   }
# }

# If not a cloudformation resource, then reference a subnet.

variable subnet_id {
  # This is the sandbox VPC.
  default = "subnet-e08e7597"
}

data "aws_subnet" "selected" {
  id = "${var.subnet_id}"
}

resource "aws_cloudformation_stack" "amibu" {
  name          = "amibu"
  capabilities  = ["CAPABILITY_IAM"]
  template_body = "${file("cloudformation/pipeline.yaml")}"

  parameters {
    BuilderVPC               = "${data.aws_subnet.selected.vpc_id}"
    BuilderPublicSubnet      = "${var.subnet_id}"
    NotificationEmailAddress = "${var.NotificationEmailAddress}"
    ServiceName              = "${var.ServiceName}"
  }
}
