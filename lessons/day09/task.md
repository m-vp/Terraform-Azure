# Task for Day09

- Using the resources created earlier, implement the lifecyle rules as below
- create before destroy lifecyle in the storage account and test it by updating the name of storage account. The newer resource should be created first and then the existing resource should be destroyed.
- create prevent destroy lifecyle in the storage account and update the storage account name and apply the changes. What did you observe?
- Create ignore changes lifecyle in the resource group and update the resource group name, apply the changes, what did you observe?
- Create a custom condition that prevent the creation of resources in the location canada central, it should through an error if we have used canada central as the resource location
