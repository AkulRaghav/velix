module github.com/velix/backend/pkg/velixtoken

go 1.22

require github.com/velix/backend/pkg/velixauth v0.0.0

require github.com/velix/backend/pkg/velixctx v0.0.0 // indirect

replace github.com/velix/backend/pkg/velixauth => ../velixauth

replace github.com/velix/backend/pkg/velixctx => ../velixctx
