package main

var cmdToLink = map[string]string{
	"ocm add componentversions":           "/docs/reference/ocm-cli/add/componentversions/",
	"ocm add references":                  "/docs/reference/ocm-cli/add/references/",
	"ocm add resource-configuration":      "/docs/reference/ocm-cli/add/resource-configuration/",
	"ocm add resources":                   "/docs/reference/ocm-cli/add/resources/",
	"ocm add routingslips":                "/docs/reference/ocm-cli/add/routingslips/",
	"ocm add source-configuration":        "/docs/reference/ocm-cli/add/source-configuration/",
	"ocm add sources":                     "/docs/reference/ocm-cli/add/sources/",
	"ocm add":                             "/docs/reference/ocm-cli/add/",
	"ocm attributes":                      "/docs/reference/ocm-cli/help/attributes/",
	"ocm bootstrap configuration":         "https://github.com/open-component-model/ocm/blob/main/docs/reference/ocm_bootstrap_configuration.md",
	"ocm bootstrap package":               "https://github.com/open-component-model/ocm/blob/main/docs/reference/ocm_bootstrap_package.md",
	"ocm check componentversions":         "/docs/reference/ocm-cli/check/componentversions/",
	"ocm check":                           "/docs/reference/ocm-cli/check/",
	"ocm clean cache":                     "/docs/reference/ocm-cli/clean/cache/",
	"ocm clean":                           "/docs/reference/ocm-cli/clean/",
	"ocm configfile":                      "/docs/reference/ocm-cli/help/configfile/",
	"ocm create componentarchive":         "/docs/reference/ocm-cli/create/componentarchive/",
	"ocm create rsakeypair":               "/docs/reference/ocm-cli/create/rsakeypair/",
	"ocm create transportarchive":         "/docs/reference/ocm-cli/create/transportarchive/",
	"ocm create":                          "/docs/reference/ocm-cli/create/",
	"ocm describe artifacts":              "/docs/reference/ocm-cli/describe/artifacts/",
	"ocm describe cache":                  "/docs/reference/ocm-cli/describe/cache/",
	"ocm describe package":                "/docs/reference/ocm-cli/describe/package/",
	"ocm describe plugins":                "/docs/reference/ocm-cli/describe/plugins/",
	"ocm describe":                        "/docs/reference/ocm-cli/describe/",
	"ocm download artifacts":              "/docs/reference/ocm-cli/download/artifacts/",
	"ocm download cli":                    "/docs/reference/ocm-cli/download/cli/",
	"ocm download componentversions":      "/docs/reference/ocm-cli/download/componentversions/",
	"ocm download resources":              "/docs/reference/ocm-cli/download/resources/",
	"ocm download":                        "/docs/reference/ocm-cli/download/",
	"ocm get artifacts":                   "/docs/reference/ocm-cli/get/artifacts/",
	"ocm get componentversions":           "/docs/reference/ocm-cli/get/componentversions/",
	"ocm get config":                      "/docs/reference/ocm-cli/get/config/",
	"ocm get credentials":                 "/docs/reference/ocm-cli/get/credentials/",
	"ocm get plugins":                     "/docs/reference/ocm-cli/get/plugins/",
	"ocm get pubsub":                      "/docs/reference/ocm-cli/get/pubsub/",
	"ocm get references":                  "/docs/reference/ocm-cli/get/references/",
	"ocm get resources":                   "/docs/reference/ocm-cli/get/resources/",
	"ocm get routingslips":                "/docs/reference/ocm-cli/get/routingslips/",
	"ocm get sources":                     "/docs/reference/ocm-cli/get/sources/",
	"ocm get":                             "/docs/reference/ocm-cli/get/",
	"ocm list componentversions":          "/docs/reference/ocm-cli/list/componentversions/",
	"ocm list":                            "/docs/reference/ocm-cli/list/",
	"ocm logging":                         "/docs/reference/ocm-cli/help/logging/",
	"ocm ocm-accessmethods":               "/docs/reference/ocm-cli/help/ocm-accessmethods/",
	"ocm ocm-downloadhandlers":            "/docs/reference/ocm-cli/help/ocm-downloadhandlers/",
	"ocm ocm-labels":                      "/docs/reference/ocm-cli/help/ocm-labels/",
	"ocm ocm-pubsub":                      "/docs/reference/ocm-cli/help/ocm-pubsub/",
	"ocm ocm-uploadhandlers":              "/docs/reference/ocm-cli/help/ocm-uploadhandlers/",
	"ocm set pubsub":                      "/docs/reference/ocm-cli/set/pubsub/",
	"ocm set":                             "/docs/reference/ocm-cli/set/",
	"ocm show tags":                       "/docs/reference/ocm-cli/show/tags/",
	"ocm show versions":                   "/docs/reference/ocm-cli/show/versions/",
	"ocm show":                            "/docs/reference/ocm-cli/show/",
	"ocm sign componentversions":          "/docs/reference/ocm-cli/sign/componentversions/",
	"ocm sign hash":                       "/docs/reference/ocm-cli/sign/hash/",
	"ocm sign":                            "/docs/reference/ocm-cli/sign/",
	"ocm toi-bootstrapping":               "/docs/reference/ocm-cli/help/toi-bootstrapping/",
	"ocm transfer artifacts":              "/docs/reference/ocm-cli/transfer/artifacts/",
	"ocm transfer commontransportarchive": "/docs/reference/ocm-cli/transfer/commontransportarchive/",
	"ocm transfer componentarchive":       "/docs/reference/ocm-cli/transfer/componentarchive/",
	"ocm transfer componentversions":      "/docs/reference/ocm-cli/transfer/componentversions/",
	"ocm transfer":                        "/docs/reference/ocm-cli/transfer/",
	"ocm verify componentversions":        "/docs/reference/ocm-cli/verify/componentversions/",
	"ocm verify":                          "/docs/reference/ocm-cli/verify/",
	"ocm":                                 "/docs/reference/ocm-cli/",
}
