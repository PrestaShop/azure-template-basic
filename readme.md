test template with these commands

`azure group create basicdep northeurope`  
```bash
azure group deployment create basicdep basicdepl1 \
   --template-uri https://raw.githubusercontent.com/PrestaShop/azure-template-basic/master/mainTemplate.json \
   --parameters-file mainTemplate.parameters.json
```
