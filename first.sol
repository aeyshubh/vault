pragma solidity ^0.8.7;
interface IInterchainQueryRouter {
    /**
     * @param _destinationDomain Domain of destination chain
     * @param target The address of the contract to query on destination chain.
     * @param queryData The calldata of the view call to make on the destination
     * chain.
     * @param callback Callback function selector on `msg.sender` and optionally
     * abi-encoded prefix arguments.
     * @return messageId The ID of the Hyperlane message encoding the query.
     */
    function query(
        uint32 _destinationDomain,
        address target,
        bytes calldata queryData,
        bytes calldata callback
    ) external returns (bytes32);
}

interface QuerydestChain {
    struct safe {
        address owner;
        bool status;
    }

    function getStatus(uint256 _safeId) external view returns (bool);
}

interface IInterchainGasPaymaster {
    function payForGas(
        bytes32 _messageId,
        uint32 _destinationDomain,
        uint256 _gasAmount,
        address _refundAddress
    ) external payable;

    function quoteGasPayment(uint32 _destinationDomain, uint256 _gasAmount)
        external
        view
        returns (uint256);
}

contract multisig {
    uint32 immutable Domain;
    address immutable iqsRouter;

    constructor(uint32 _domain,address _iqs){
        Domain = _domain;
        iqsRouter = _iqs;
    }
    struct addr {
        address a1;
        address a2;
        bool sts1;
        bool sts2;
        uint256 balance;
        uint256[] timestamps;
    }
    mapping(uint256 => addr) public safeOwner;
    uint256 public safeId;

    function writeOwner(uint256 _safeId, bool _sts) external {
        safeOwner[_safeId].sts2 = _sts;
    }
//Give contract address of second
    function queryOwner(uint256 _safeId, address _contractAddress)
        external
        payable
        returns (bytes32)
    {
        bytes memory _ownerCall = abi.encodeWithSignature(
            "getStatus(uint256)",
            (_safeId)
        );
        // The return value of ownerOf() will be automatically appended when
        // making this callback
        bytes memory _callback = abi.encodePacked(
            this.writeOwner.selector,
            _safeId
        );
        bytes32 messageId = IInterchainQueryRouter(iqsRouter).query(
            Domain,
            _contractAddress,
            _ownerCall,
            _callback
        );

        IInterchainGasPaymaster igp = IInterchainGasPaymaster(
            0xF90cB82a76492614D07B82a7658917f3aC811Ac1
        );
        // Pay with the msg.value
        igp.payForGas{value: msg.value}(
            // The ID of the message
            messageId,
            // Destination domain
            Domain,
            // The total gas amount. This should be the
            // overhead gas amount (80,000 gas) + gas used by the query being made
            80000 + 100000,
            // Refund the msg.sender
            msg.sender
        );

        return (messageId);
    }
//CAll this first

    function setSigner(address _crossChainAddress) public returns (uint256) {
        safeId++;
        safeOwner[safeId].a1 = msg.sender;
        safeOwner[safeId].a2 = _crossChainAddress;
        return (safeId);
    }
    function SetApproval(uint256 _safeId) public {
        require(
            msg.sender == safeOwner[_safeId].a1 &&
                safeOwner[_safeId].sts1 == false,
            "You are not the owner of the safe"
        );
        safeOwner[_safeId].sts1 = true;
    }

    //Bank Account Number
    function storeFunds(uint256 _safeId) external payable {
        safeOwner[_safeId].balance = safeOwner[_safeId].balance + msg.value;
    }

    function returnOwner(uint256 _safeId) external view returns (address) {
        return (safeOwner[_safeId].a2);
    }

    function getOwner(bytes memory _encodedData)
        external
        pure
        returns (address _owner2, uint256 _safeId)
    {
        (_owner2, _safeId) = abi.decode(_encodedData, (address, uint256));
    }

    function withdraw(uint256 _safeId, address payable _a1) public payable {
        require(
            safeOwner[_safeId].sts1 == true && safeOwner[_safeId].sts2 == true,
            "Both parties have not aggred to widthraw"
        );
        _a1.transfer(safeOwner[_safeId].balance);
    }
}
