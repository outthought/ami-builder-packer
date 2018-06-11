# Examine a VPC and create cloudformation stack from its parameters.

variable NotificationEmailAddress {
  description = "The email address for SNS notifications."
  type        = "string"
}

variable ServiceName {
  description = "The name of the CloudFormation Stack and it's resources."
  type        = "string"
}

# If the target vpc is from a cloudformation stack, then we may use the aws_cloudformation_stack data source.

variable cfn_vpc {
  description = "Target VPC. e.g. dev-spsc-VPC"
  type        = "string"
  default     = "dev-spsc-VPC"
}

data "aws_cloudformation_stack" "cfn" {
  name = "${var.cfn_vpc}"
}

resource "aws_cloudformation_stack" "amibuilder" {
  name          = "${var.ServiceName}"
  capabilities  = ["CAPABILITY_IAM"]
  template_body = "${file("pipeline.yaml")}"

  parameters {
    BuilderPublicSubnet      = "${element(split(",", data.aws_cloudformation_stack.cfn.outputs.internalSubnets), 2)}"
    BuilderVPC               = "${data.aws_cloudformation_stack.cfn.outputs.VPC}"
    NotificationEmailAddress = "${var.NotificationEmailAddress}"
    ServiceName              = "${var.ServiceName}"
  }
  tags = {
    "sps:unit" = "techops"
    "sps:product" = "syseng"
    "sps:subproduct" = "amibuild"
  }
}

# If not a cloudformation resource, then reference a subnet.

# variable subnet_id {
#   # This is the sandbox VPC.
#   default = "subnet-e08e7597"
# }

# data "aws_subnet" "selected" {
#   id = "${var.subnet_id}"
# }

# resource "aws_cloudformation_stack" "amibuilder" {
#   name          = "${var.ServiceName}"
#   capabilities  = ["CAPABILITY_IAM"]
#   template_body = "${file("pipeline.yaml")}"

#   parameters {
#     BuilderVPC               = "${data.aws_subnet.selected.vpc_id}"
#     BuilderPublicSubnet      = "${var.subnet_id}"
#     NotificationEmailAddress = "${var.NotificationEmailAddress}"
#     ServiceName              = "${var.ServiceName}"
#   }
# }

output cfn_outputs {
  value = "${aws_cloudformation_stack.amibuilder.outputs}"
}

output cfn_id {
  value = "${aws_cloudformation_stack.amibuilder.id}"
}
