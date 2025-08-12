import Blob "mo:base/Blob";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";

actor StorageCanister {
    private var files = HashMap.HashMap<Text, Blob>(1, Text.equal, Text.hash);

    public func upload(name : Text, content : Blob) : async () {
        files.put(name, content);
    };

    public query func get(name : Text) : async ?Blob {
        files.get(name);
    };

    public query func http_request(request : { method : Text; url : Text; headers : [(Text, Text)]; body : Blob }) : async { status_code : Nat16; headers : [(Text, Text)]; body : Blob } {
        let path = Text.trimStart(request.url, #text "http://storage_canister.localhost:8000/");
        switch (files.get(path)) {
            case (?blob) {
                {
                    status_code = 200;
                    headers = [("Content-Type", "model/gltf-binary"), ("Content-Length", Nat.toText(blob.size()))];
                    body = blob;
                };
            };
            case null {
                {
                    status_code = 404;
                    headers = [];
                    body = Text.encodeUtf8("File not found");
                };
            };
        };
    };
}
