ngx.req.read_body()
args = ngx.req.get_post_args()
if args then
ngx.log(ngx.ERR ,"post para", cjson.encode(args))
end

