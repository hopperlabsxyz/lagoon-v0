// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

// 💬 ABOUT
// Gnosis Safe transaction batching script

// 🧩 MODULES
import {Script, StdChains, StdStorage, VmSafe, console2, stdJson, stdMath, stdStorageSafe} from "forge-std/Script.sol";

import {Surl} from "./Surl.l.sol";
import {Script, console} from "forge-std/Script.sol";

// ⭐️ SCRIPT
abstract contract BatchScript is Script {
    using stdJson for string;
    using Surl for *;

    // Hash constants
    // Safe version for this script, hashes below depend on this
    string private constant VERSION = "1.3.0";

    // keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    // keccak256(
    //     "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256
    // gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    // );
    bytes32 private constant SAFE_TX_TYPEHASH = 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;

    // Chain ID, configured by chain.
    uint256 private chainId = block.chainid;

    // Safe API base URL, configured by chain.
    string private SAFE_API_BASE_URL;
    string private constant SAFE_API_MULTISIG_SEND = "/multisig-transactions/";

    // Wallet information
    bytes32 private walletType;
    uint256 private mnemonicIndex;
    bytes32 private privateKey;

    bytes32 private constant LOCAL = keccak256("local");
    bytes32 private constant LEDGER = keccak256("ledger");

    // Address to send transaction from
    address private safe;

    enum Operation {
        CALL,
        DELEGATECALL
    }

    struct Batch {
        address to;
        uint256 value;
        bytes data;
        Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 nonce;
        bytes32 txHash;
        bytes signature;
    }

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        Operation operation;
    }

    Transaction[] public transactions;
    address public safe_signer;

    // Modifiers

    modifier isBatch(
        address safe_
    ) {
        // Set the chain ID

        // Set the Safe API base URL based on chain
        if (chainId == 1) {
            SAFE_API_BASE_URL = "https://safe-transaction-mainnet.safe.global/api/v1/safes/";
        } else if (chainId == 5) {
            SAFE_API_BASE_URL = "https://safe-transaction-goerli.safe.global/api/v1/safes/";
        } else if (chainId == 8453) {
            SAFE_API_BASE_URL = "https://safe-transaction-base.safe.global/api/v1/safes/";
        } else if (chainId == 42_161) {
            SAFE_API_BASE_URL = "https://safe-transaction-arbitrum.safe.global/api/v1/safes/";
        } else if (chainId == 43_114) {
            SAFE_API_BASE_URL = "https://safe-transaction-avalanche.safe.global/api/v1/safes/";
        } else {
            revert("Unsupported chain");
        }

        // Store the provided safe address
        safe = safe_;

        // Load wallet information
        walletType = keccak256(abi.encodePacked(vm.envString("WALLET_TYPE")));
        if (walletType == LOCAL) {
            privateKey = vm.envBytes32("PRIVATE_KEY");
        } else if (walletType == LEDGER) {
            safe_signer = vm.envAddress("SAFE_SIGNER");
        } else {
            revert("Unsupported wallet type");
        }

        // Run batch
        _;
    }

    // Functions to consume in a script

    function addToBatch(address to_, uint256 value_, bytes memory data_) internal returns (bytes memory) {
        // Add transaction to transactions array
        transactions.push(Transaction({to: to_, value: value_, data: data_, operation: Operation.CALL}));

        // Simulate transaction and get return value
        vm.prank(safe);
        (bool success, bytes memory data) = to_.call{value: value_}(data_);
        if (success) {
            return data;
        } else {
            revert(string(data));
        }
    }

    function addToBatch(address to_, bytes memory data_) internal returns (bytes memory) {
        // Add transaction to transactions array
        transactions.push(Transaction({to: to_, value: 0, data: data_, operation: Operation.CALL}));

        // Simulate transaction and get return value
        vm.prank(safe);
        (bool success, bytes memory data) = to_.call(data_);
        if (success) {
            return data;
        } else {
            revert(string(data));
        }
    }

    function executeBatch(
        bool send_
    ) internal {
        uint256 nonce = _getNonce(safe);

        for (uint256 i = 0; i < transactions.length; i++) {
            Transaction memory txn = transactions[i];
            Batch memory batch = Batch({
                to: txn.to,
                value: txn.value,
                data: txn.data,
                operation: txn.operation,
                safeTxGas: 0,
                baseGas: 0,
                gasPrice: 0,
                gasToken: address(0),
                refundReceiver: address(0),
                nonce: nonce + i,
                txHash: bytes32(0),
                signature: bytes("")
            });

            batch.txHash = _getTransactionHash(safe, batch);

            if (send_) {
                batch = _signBatch(safe, batch);
                _sendBatch(safe, batch);
            }
        }
    }

    function _signBatch(address safe_, Batch memory batch_) private returns (Batch memory) {
        // Get the typed data to sign
        string memory typedData = _getTypedData(safe_, batch_);
        // Construct the sign command
        string memory commandStart = "cast wallet sign ";
        string memory wallet;
        if (walletType == LOCAL) {
            wallet = string.concat("--private-key ", vm.toString(privateKey), " ");
        } else if (walletType == LEDGER) {
            console.log("safe_signer", safe_signer);
            mnemonicIndex = 20;
            wallet = string.concat("--ledger --mnemonic-index ", vm.toString(mnemonicIndex - 1), " ");
        } else {
            revert("Unsupported wallet type");
        }
        string memory commandEnd = "--data ";

        // Sign the typed data from the CLI and get the signature
        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = string.concat(commandStart, wallet, commandEnd, "'", typedData, "'");
        bytes memory signature = vm.ffi(inputs);

        // Set the signature on the batch
        batch_.signature = signature;

        return batch_;
    }

    function _sendBatch(address safe_, Batch memory batch_) private {
        string memory endpoint = _getSafeAPIEndpoint(safe_);

        // Create json payload for API call to Gnosis transaction service
        string memory placeholder = "";
        placeholder.serialize("safe", safe_);
        placeholder.serialize("to", batch_.to);
        placeholder.serialize("value", batch_.value);
        placeholder.serialize("data", batch_.data);
        placeholder.serialize("operation", uint256(batch_.operation));
        placeholder.serialize("safeTxGas", batch_.safeTxGas);
        placeholder.serialize("baseGas", batch_.baseGas);
        placeholder.serialize("gasPrice", batch_.gasPrice);
        placeholder.serialize("nonce", batch_.nonce);
        placeholder.serialize("gasToken", address(0));
        placeholder.serialize("refundReceiver", address(0));
        placeholder.serialize("contractTransactionHash", batch_.txHash);
        placeholder.serialize("signature", batch_.signature);
        string memory payload = placeholder.serialize("sender", safe_signer);
        console.log("payload");
        console.log(payload);
        // Send batch
        (uint256 status, bytes memory data) = endpoint.post(_getHeaders(), payload);

        if (status == 201) {
            console2.log("Batch sent successfully");
        } else {
            console2.log(string(data));
            revert("Send batch failed!");
        }
    }

    function _getTransactionHash(address safe_, Batch memory batch_) private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                hex"1901",
                keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, chainId, safe_)),
                keccak256(
                    abi.encode(
                        SAFE_TX_TYPEHASH,
                        batch_.to,
                        batch_.value,
                        keccak256(batch_.data),
                        batch_.operation,
                        batch_.safeTxGas,
                        batch_.baseGas,
                        batch_.gasPrice,
                        address(0),
                        address(0),
                        batch_.nonce
                    )
                )
            )
        );
    }

    function _getTypedData(address safe_, Batch memory batch_) private returns (string memory) {
        // Create EIP712 structured data for the batch transaction to sign externally via cast

        // EIP712Domain Field Types
        string[] memory domainTypes = new string[](2);
        string memory t = "domainType0";
        vm.serializeString(t, "name", "verifyingContract");
        domainTypes[0] = vm.serializeString(t, "type", "address");
        t = "domainType1";
        vm.serializeString(t, "name", "chainId");
        domainTypes[1] = vm.serializeString(t, "type", "uint256");

        // SafeTx Field Types
        string[] memory txnTypes = new string[](10);
        t = "txnType0";
        vm.serializeString(t, "name", "to");
        txnTypes[0] = vm.serializeString(t, "type", "address");
        t = "txnType1";
        vm.serializeString(t, "name", "value");
        txnTypes[1] = vm.serializeString(t, "type", "uint256");
        t = "txnType2";
        vm.serializeString(t, "name", "data");
        txnTypes[2] = vm.serializeString(t, "type", "bytes");
        t = "txnType3";
        vm.serializeString(t, "name", "operation");
        txnTypes[3] = vm.serializeString(t, "type", "uint8");
        t = "txnType4";
        vm.serializeString(t, "name", "safeTxGas");
        txnTypes[4] = vm.serializeString(t, "type", "uint256");
        t = "txnType5";
        vm.serializeString(t, "name", "baseGas");
        txnTypes[5] = vm.serializeString(t, "type", "uint256");
        t = "txnType6";
        vm.serializeString(t, "name", "gasPrice");
        txnTypes[6] = vm.serializeString(t, "type", "uint256");
        t = "txnType7";
        vm.serializeString(t, "name", "gasToken");
        txnTypes[7] = vm.serializeString(t, "type", "address");
        t = "txnType8";
        vm.serializeString(t, "name", "refundReceiver");
        txnTypes[8] = vm.serializeString(t, "type", "address");
        t = "txnType9";
        vm.serializeString(t, "name", "nonce");
        txnTypes[9] = vm.serializeString(t, "type", "uint256");

        // Create the top level types object
        t = "topLevelTypes";
        t.serialize("EIP712Domain", domainTypes);
        string memory types = t.serialize("SafeTx", txnTypes);

        // Create the message object
        string memory m = "message";
        m.serialize("to", batch_.to);
        m.serialize("value", batch_.value);
        m.serialize("data", batch_.data);
        m.serialize("operation", uint256(batch_.operation));
        m.serialize("safeTxGas", batch_.safeTxGas);
        m.serialize("baseGas", batch_.baseGas);
        m.serialize("gasPrice", batch_.gasPrice);
        m.serialize("gasToken", address(0));
        m.serialize("refundReceiver", address(0));
        string memory message = m.serialize("nonce", batch_.nonce);

        // Create the domain object
        string memory d = "domain";
        d.serialize("verifyingContract", safe_);
        string memory domain = d.serialize("chainId", chainId);

        // Create the payload object
        string memory p = "payload";
        p.serialize("types", types);
        vm.serializeString(p, "primaryType", "SafeTx");
        p.serialize("domain", domain);
        string memory payload = p.serialize("message", message);

        payload = _stripSlashQuotes(payload);

        return payload;
    }

    function _stripSlashQuotes(
        string memory str_
    ) private returns (string memory) {
        // Remove slash quotes from string
        string memory command = string.concat(
            "sed 's/",
            '\\\\"/"',
            "/g; s/",
            '\\"',
            "\\[/\\[/g; s/",
            '\\]\\"',
            "/\\]/g; s/",
            '\\"',
            "{/{/g; s/",
            '}\\"',
            "/}/g;' <<< "
        );

        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = string.concat(command, "'", str_, "'");
        bytes memory res = vm.ffi(inputs);

        return string(res);
    }

    function _getNonce(
        address safe_
    ) private returns (uint256) {
        string memory endpoint = string.concat(_getSafeAPIEndpoint(safe_));
        (uint256 status, bytes memory data) = endpoint.get();
        if (status == 200) {
            string memory resp = string(data);
            return resp.readUint(".countUniqueNonce");
        } else {
            revert("Get nonce failed!");
        }
    }

    function _getSafeAPIEndpoint(
        address safe_
    ) private view returns (string memory) {
        return string.concat(SAFE_API_BASE_URL, vm.toString(safe_), SAFE_API_MULTISIG_SEND);
    }

    function _getHeaders() private pure returns (string[] memory) {
        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";
        return headers;
    }
}
