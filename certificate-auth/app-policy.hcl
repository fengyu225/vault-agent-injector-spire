path "kv/data/app/config" {
  capabilities = ["read"]
}

path "kv/data/app/config/*" {
  capabilities = ["read"]
}

path "kv/metadata/app/config" {
  capabilities = ["read", "list"]
}
