provider "oci" {
}
 
// Compartment 1 : Shadab-Dev
resource "oci_core_vcn" "terraform-demo-vcn" {
  cidr_block     = "10.0.0.0/16"
  dns_label      = "myvcn"
  display_name   = "terraform-demo-vcn"
  compartment_id = "ocid1.compartment.oc1..aaaaaaaanls4erycqd5tq"
}
