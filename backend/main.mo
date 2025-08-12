import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import List "mo:base/List";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import Error "mo:base/Error";

actor NFTCanister {
    public type TokenId = Nat;
    public type UseCase = {#FPS; #VR; #Decoration; #Vehicle; #Weapon};
    public type Metadata = {
        name: Text;
        description: Text;
        tags: [Text];
        useCases: [UseCase];
        modelUrl: Text;
    };
    
    public type Listing = {
        tokenId: TokenId;
        seller: Principal;
        price: Nat;
    };

    private var nextTokenId: TokenId = 0;
    private var nfts = HashMap.HashMap<TokenId, Metadata>(1, Nat.equal, Hash.hash);
    private var owners = HashMap.HashMap<TokenId, Principal>(1, Nat.equal, Hash.hash);
    private var userNFTs = HashMap.HashMap<Principal, List.List<TokenId>>(1, Principal.equal, Principal.hash);
    private var listings = HashMap.HashMap<TokenId, Listing>(1, Nat.equal, Hash.hash);
    
    // Storage canister principal - will be set after deployment
    private var storageCanisterPrincipal : ?Principal = null;
    
    // Function to set the storage canister principal
    public shared(msg) func setStorageCanister(principal : Principal) : async Bool {
        // Only the controller (deployer) can set the storage canister
        if (msg.caller != Principal.fromText("2vxsx-fae")) {
            return false;
        };
        storageCanisterPrincipal := ?principal;
        return true;
    };

    public shared(msg) func mintNFT(metadata: Metadata, modelFile: Blob) : async TokenId {
        switch (storageCanisterPrincipal) {
            case (?principal) {
                let storageCanister = actor(Principal.toText(principal)) : actor {
                    upload : (Text, Blob) -> async ();
                    get : (Text) -> async ?Blob;
                };
                
                let tokenId = nextTokenId;
                nextTokenId += 1;
                
                let modelName = "model_" # Nat.toText(tokenId) # ".glb";
                await storageCanister.upload(modelName, modelFile);
                let modelUrl = "http://storage_canister.localhost:8000/" # modelName;
                
                let updatedMetadata = {
                    name = metadata.name;
                    description = metadata.description;
                    tags = metadata.tags;
                    useCases = metadata.useCases;
                    modelUrl = modelUrl;
                };
                
                nfts.put(tokenId, updatedMetadata);
                owners.put(tokenId, msg.caller);
                
                let userTokens = switch (userNFTs.get(msg.caller)) {
                    case null { List.nil<TokenId>() };
                    case (?tokens) { tokens };
                };
                userNFTs.put(msg.caller, List.push(tokenId, userTokens));
                
                return tokenId;
            };
            case null {
                // Return an error instead of throwing
                return 0;
            };
        }
    };

    public shared(msg) func listForSale(tokenId: TokenId, price: Nat) : async Bool {
        switch (owners.get(tokenId)) {
            case (?owner) {
                if (owner != msg.caller) return false;
                listings.put(tokenId, {
                    tokenId = tokenId;
                    seller = msg.caller;
                    price = price;
                });
                return true;
            };
            case null { return false; };
        }
    };

    public shared(msg) func buyNFT(tokenId: TokenId) : async Bool {
        switch (listings.get(tokenId)) {
            case (?listing) {
                let buyer = msg.caller;
                let seller = listing.seller;
                
                owners.put(tokenId, buyer);
                
                let sellerTokens = switch (userNFTs.get(seller)) {
                    case null { List.nil<TokenId>() };
                    case (?tokens) { List.filter<TokenId>(tokens, func (t) { t != tokenId }) };
                };
                userNFTs.put(seller, sellerTokens);
                
                let buyerTokens = switch (userNFTs.get(buyer)) {
                    case null { List.nil<TokenId>() };
                    case (?tokens) { tokens };
                };
                userNFTs.put(buyer, List.push(tokenId, buyerTokens));
                
                listings.delete(tokenId);
                
                return true;
            };
            case null { return false; };
        }
    };

    public query func getListings() : async [(TokenId, Listing)] {
        return Iter.toArray(listings.entries());
    };

    public query func getNFT(tokenId: TokenId): async ?Metadata {
        nfts.get(tokenId)
    };

    public query func getUserNFTs(user: Principal): async [TokenId] {
        switch (userNFTs.get(user)) {
            case null { [] };
            case (?tokens) { List.toArray(tokens) };
        }
    };

    public query func getOwner(tokenId: TokenId): async ?Principal {
        owners.get(tokenId)
    };
}
