module Terraforming
  module Resource
    class CloudFrontDistribution
      include Terraforming::Util

      # ClientとResourceの違い
      def self.tf(client: Aws::CloudFront::Client.new)
        self.new(client).tf
      end

      def self.tfstate(client: Aws::CloudFront::Client.new)
        self.new(client).tfstate
      end

      def initialize(client)
        @client = client
      end

      def tf
        apply_template(@client, "tf/cloud_front_distribution")
      end

      def tfstate
        instances.inject({}) do |resources, instance|
          in_vpc = in_vpc?(instance)
          block_devices = block_devices_of(instance)

          attributes = {
            "ami" => instance.image_id,
            "associate_public_ip_address" => associate_public_ip?(instance).to_s,
            "availability_zone" => instance.placement.availability_zone,
            "ebs_block_device.#" => ebs_block_devices_in(block_devices, instance).length.to_s,
            "ebs_optimized" => instance.ebs_optimized.to_s,
            "ephemeral_block_device.#" => "0", # Terraform 0.6.1 cannot fetch this field from AWS
            "id" => instance.instance_id,
            "instance_type" => instance.instance_type,
            "monitoring" => monitoring_state(instance).to_s,
            "private_dns" => instance.private_dns_name,
            "private_ip" => instance.private_ip_address,
            "public_dns" => instance.public_dns_name,
            "public_ip" => instance.public_ip_address,
            "root_block_device.#" => root_block_devices_in(block_devices, instance).length.to_s,
            "security_groups.#" => in_vpc ? "0" : instance.security_groups.length.to_s,
            "source_dest_check" => instance.source_dest_check.to_s,
            "tenancy" => instance.placement.tenancy,
            "vpc_security_group_ids.#" => in_vpc ? instance.security_groups.length.to_s : "0",
          }

          placement_group = instance.placement.group_name
          attributes["placement_group"] = placement_group unless placement_group.empty?

          attributes["subnet_id"] = instance.subnet_id if in_vpc?(instance)

          resources["aws_instance.#{module_name_of(instance)}"] = {
            "type" => "aws_instance",
            "primary" => {
              "id" => instance.instance_id,
              "attributes" => attributes,
              "meta" => {
                "schema_version" => "1"
              }
            }
          }

          resources
        end
      end
    end
  end
end
