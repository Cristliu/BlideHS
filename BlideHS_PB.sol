pragma solidity ^0.4.19;

contract BlideHSPB{
    
    mapping(address => bool) PTlist;//PT list，false for PF
    mapping(uint => bool) HDBlist;//HD Blacklist

    address public Mg = 0xDd24466bfc2798fCF696e808638CA2dE0725361D;
    modifier onlyMg() {
        if (msg.sender == Mg)
        _;
        else revert();
    }

//1.Register or Update Identity
    function UpIdentity_on(address pnf, bool isPT) onlyMg public returns(bool){
        PTlist[pnf] = isPT;
        return isPT;
    }
    function GetIdentity_on(address pnf) public view returns(bool){
        return PTlist[pnf];
    }

//Mg under the chain guarantees that no duplicate HD status will be uploaded, unless the update of the blacklist list
    function UpHDs_on(uint[] HDid,  bool[] isblack) onlyMg public returns(bool){
        for(uint i=0;i<HDid.length;i++){
            HDBlist[HDid[i]] = isblack[i];
        }
        return true;
    }

    function Report_on(bytes32 _Hmsgs, uint[] HDid) public returns(bool){
//_Hmsgs is just a proof of storage, no need to deal with        
        for(uint i=0;i<HDid.length;i++){
            HDBlist[HDid[i]] = true;
        }
        return true;
    }

    function GetBlist(uint HDid) public view returns(bool){
        return HDBlist[HDid]; 
    }
}