# Why do we create machine images?

We create machine images in order to customize the initial state of the machines we run. Each machine image begins with a public machine image, and ends with a private, custom-modified machine image. The modification process is to instantiate, configure, and then capture the instance, with the changes, into an image. At present this is in the form of an Amazon machine image, or AMI. A select set of configurations modify the instance from the original state, into a configured state, creating a branch of the upstream machine image.

The select set of configurations applied may be referred to as a configuration delta. This configuration delta could be applied to instances when they are instantiated, using a public source machine image directly. However, the potential benefits of a custom machine image include, less time to put an instance into a desired state, and fewer dependencies at runtime on externally available repositories, necessary to achieve the configuration delta.

# Ansible Role

This role expresses the configuration delta for each machine image we wish to deploy.

# Operating System Families

Current list of compatible operating systems, differentiated by `ansible_os_family` value.

- `RedHat`
- `Debian`
