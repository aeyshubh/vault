//SPDX-License-Identifier:MIT
pragma solidity >0.8.7;
interface IInterchainQueryRouter {
    /**
     * @param _destinationDomain Domain of destination chain
     * @param target The address of the contract to query on destination chain.
     * @param queryData The calldata of the view call to make on the destination
     * chain.
     * @param callback Callback function selector on `msg.sender` and optionally
     * abi-encoded prefix argu
     ments.
     * @return messageId The ID of the Hyperlane message encoding the query.
     */
    function query(
        uint32 _destinationDomain,
        address target,
        bytes calldata queryData,
        bytes calldata callback
    ) external returns (bytes32);
}
/* interface queryOwner {
    struct addr {
        address a1;
        address a2;
        bool sts1;
        bool sts2;
        uint256 balance;
        uint256[] timestamps;
    }
    function returnOwner(uint256 _safeId) external view returns (address);
} */
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
contract call {
    uint32 immutable public Domain;
    address immutable public iqsRouter;

    constructor(uint32 _domain,address _iqs){
        Domain = _domain;
        iqsRouter = _iqs;
    }
    struct safe {
        address owner;
        bool status;
    }
    mapping(uint256 => safe) safeOwner;

    function setStatus(uint256 _safeId) public {
        require(msg.sender == safeOwner[_safeId].owner, "Intruder spotted");
        safeOwner[_safeId].status = true;
    }

    function getStatus(uint256 _safeId) public view returns (bool) {
        return safeOwner[_safeId].status;
    }

    function getOwner(uint256 _safeId)
        public view
        returns (address _owner2, uint256 _safeIdd)
    {
        return (safeOwner[_safeId].owner,_safeId);
    }

    function writeOwner(uint256 _safeId, address _owner) external {
        safeOwner[_safeId].owner = _owner;
    }

    function queryOwner(uint256 _safeId, address _contractAddress)
        external payable
        returns (bytes32)
    {
        // uint256 _label = uint256(keccak256(_labelStr));
        bytes memory _ownerCall = abi.encodeWithSignature("returnOwner(uint256)", (_safeId));
        // The return value of ownerOf() will be automatically appended when
        // making this callback
        bytes memory _callback = abi.encodePacked(
            this.writeOwner.selector,
            _safeId
        );
        bytes32 messageId =
            IInterchainQueryRouter(iqsRouter).query(
                Domain,
                _contractAddress,
                _ownerCall,
                _callback
            );
 
        IInterchainGasPaymaster igp = IInterchainGasPaymaster(
        0xF987d7edcb5890cB321437d8145E3D51131298b6
    );
    // Pay with the msg.value
    igp.payForGas{ value: msg.value }(
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
 
        return(messageId);
    }
}
