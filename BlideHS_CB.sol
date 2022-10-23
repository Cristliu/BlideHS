pragma solidity ^ 0.4.19;

library SafeMath {
  function mul(uint256 a, uint256 b) internal returns (uint256) {
    uint256 c = a * b;
    require(a == 0 || c / a == b);
    return c;
  }
  function div(uint256 a, uint256 b) internal returns (uint256) {
    uint256 c = a / b;
    return c;
  }
  function sub(uint256 a, uint256 b) internal returns (uint256) {
    require(b <= a);
    return a - b;
  }
  function add(uint256 a, uint256 b) internal returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }
}

contract BlideHSCB{
    using SafeMath for uint256;

    address public MSP = 0x852c64a3299f44653bdf82e5b3a62177dda27a78;
    address public CSP = 0x9b60a356df119a04ffe94927094f6a4e03fefc97;
    
    uint constant issuefee = 100;
    uint constant updatefee = 50;
    
    mapping (address => uint) Balance; //Get the balance of address
    mapping (address => bool) PnFlist;//PnF list
    mapping (address => bool) HClist;//HC list
    mapping (address => uint) IDmaplist;//ID_off list

    struct EHRStruct{
        bytes32 hash;//Unique Identification
        address pnfaddress;
        bytes32 hkw;
        address[] AuIDs;
        uint tm;
        bool isupload;//bool default false
        bool isarchived;
    }
    mapping(bytes32 => EHRStruct)  EHRfromHashLists;

    struct DiaEduStruct{
        bytes32 hash;//Unique Identification
        address hcaddress;
        address pnfaddress;
        bytes32 hkw;
        uint fee;
        bool isupload;//bool default false
        bool ispaid;
    }
    mapping(bytes32 => DiaEduStruct)  DiaEdufromHashLists;


    modifier onlyMSP() {
        if (msg.sender == MSP)
        _;
        else  revert();
    }

    modifier onlyCSP() {
        if (msg.sender == CSP)
        _;
        else  revert();
    }

    modifier onlyPnF() {
        if (PnFlist[msg.sender])
        _;
        else  revert();
    }

    modifier onlyHC() {
        if (HClist[msg.sender])
        _;
        else  revert();
    }
    modifier onlyHCforPnF(address to_PnF) {
        if (HClist[msg.sender] && PnFlist[to_PnF])
        _;
        else  revert();
    }
    modifier onlyHCforCSP(address to_CSP) {
        if (HClist[msg.sender] && to_CSP == CSP)
        _;
        else  revert();
    }

    function UpCSP(address NewCSPaddr) onlyMSP public returns(address){
        CSP = NewCSPaddr;
        return NewCSPaddr;
    }


    event _register(//Record the registration operation to the log // Specific to HC
        address indexed _pnforhcaddress,
        bytes32[] indexed _S
    );

    function Register_on(bool _isHC, uint _idoff, address _pnforhcaddress, uint amount, bytes32[] S) onlyMSP public returns(bool) {
        if(_isHC == false){// 0 - PnF
            PnFlist[_pnforhcaddress] = true;
        }
        else{
            HClist[_pnforhcaddress] = true;
            _register(_pnforhcaddress,S); // Specific to HC
        }
        IDmaplist[_pnforhcaddress] = _idoff;
        Balance [_pnforhcaddress] = Balance [_pnforhcaddress].add(amount) ;
        return true;
    }

    function GetIDoff(address _pnforhcaddress) onlyMSP public view returns(uint){
        return IDmaplist[_pnforhcaddress];
    }

    function Update_on(address _pnforhcaddress,bytes32[] S) onlyMSP public returns(bool) {//MSP guarantees that addr is a registered address, same below
        _register(_pnforhcaddress,S);
        return true;
    }

    function MintCoins(address addr , uint amount) onlyMSP public returns(bool){
        Balance [addr] = Balance [addr].add(amount) ;
        return true;
    }
    function DrawCoins(address addr , uint amount) onlyMSP public returns(bool){ 
         Balance [addr] = Balance [addr].sub(amount) ;
         return true;
    }

    function GetCoins() public view returns(uint){
        return Balance[msg.sender];
    }

//H(CT) H(KW) AuIDs
    function Issue_PnF(bytes32 _Hct, bytes32 _Hkw ,address[] _AuIDs, uint _Tm) onlyPnF public returns(bool){
        EHRStruct storage EHRCT = EHRfromHashLists[_Hct];// Create an EHRStruct
        require(EHRCT.isupload == false);//Do not allow repeated uploads of the same EHR; avoid transaction creation and gas consumption
        Balance [msg.sender] = Balance [msg.sender].sub(issuefee);
        //Receive a defined number of tokens for Issue_PnF operation
        Balance [MSP] = Balance [MSP].add(issuefee);
        EHRCT.pnfaddress = msg.sender;
        EHRCT.hash = _Hct;
        EHRCT.hkw = _Hkw;
        EHRCT.AuIDs = _AuIDs;
        EHRCT.tm = _Tm;
        EHRCT.isupload = true;
        return true;
    }


    function UpIssue_PnF(bytes32 _Hct, address[] _AuIDs ) onlyPnF public returns(bool){
        //// by appending parameters, continue to update hkw, tm if available; otherwise, update only AuIDs
        EHRStruct storage EHRCT = EHRfromHashLists[_Hct];
        require(EHRCT.isupload == true);
        require(EHRCT.pnfaddress == msg.sender);
        Balance [msg.sender] = Balance [msg.sender].sub(updatefee);
        //Receive a defined number of tokens for UpIssue_PnF operation
        Balance [MSP] = Balance [MSP].add(updatefee);
        EHRCT.AuIDs = _AuIDs;
        return true;
    }


    //Archive the HCT and no longer accept access
    function UpHctfromPnF(bytes32 _Hct) onlyPnF public returns(bool) {
        EHRStruct storage EHRCT = EHRfromHashLists[_Hct];//这个方法跟直接创建数组的开销应该差不多吧
        require(EHRCT.isupload == true && EHRCT.pnfaddress == msg.sender && EHRCT.isarchived==false);
        EHRCT.isarchived==true;
        return true;
    } 



    event _UpCTlResp_CSP(
        address indexed _hcaddress,
        bytes32 indexed _Hct
    );//This event is known to both PnF and HC

    function UpCTlResp_CSP(bytes32 _Hct, address _hcaddress) onlyCSP public returns(uint){
         EHRStruct storage EHRCT = EHRfromHashLists[_Hct];
         require(EHRCT.isupload);
         require(HClist[_hcaddress]);
         //CSP itself ensures that it does not repeatedly upload HC that is not the first access 
         //CSP ensures that tm is greater than 0 before subtracting
         EHRCT.tm = EHRCT.tm.sub(1);
         _UpCTlResp_CSP(_hcaddress,_Hct);
         return  EHRCT.tm;
    } 

//The event log ====CSP calls the function that declares that _hcaddress accessed _Hct, and if _hcaddress feels that it did not, it can initiate a claim


    function CheckHCTtm(bytes32 _Hct) view public returns(uint){//
        return EHRfromHashLists[_Hct].tm;
    }

    function Issue_HC(address _pnfaddress, bytes32 _Hct_DiaEdu, bytes32 _Hkw_DiaEdu, uint _Fee) onlyHCforPnF(_pnfaddress)  public returns(bool){
        //_Hct_DiaEdu includes a detailed list of fees
        DiaEduStruct storage DECT = DiaEdufromHashLists[_Hct_DiaEdu];// Create a DiaEduStruct
        require(DECT.isupload == false);
        Balance [msg.sender] = Balance [msg.sender].sub(issuefee) ;
        Balance [MSP] = Balance [MSP].add(issuefee) ;
        DECT.hash = _Hct_DiaEdu;
        DECT.hcaddress = msg.sender;
        DECT.pnfaddress = _pnfaddress;
        DECT.fee = _Fee;//Once uploaded, it cannot be modified
        DECT.hkw = _Hkw_DiaEdu;
        DECT.isupload = true;
        return true;
    }

    event _UpDEHCTResp_CSP(
        address indexed _pnfaddress,
        bytes32 indexed _Hct_DiaEdu
    );//This event is known to both PnF and HC

    function UpCTrResp_CSP(bytes32 _Hct_DiaEdu, address _pnfaddress) onlyCSP public returns(bool){//Cloud sends report = this diagnosis has been captured by pnf
        DiaEduStruct storage DECT = DiaEdufromHashLists[_Hct_DiaEdu];
        require(DECT.isupload && DECT.pnfaddress == _pnfaddress);
        _UpDEHCTResp_CSP(_pnfaddress,_Hct_DiaEdu);
        return true;
    }


    function FeBack_PnF(bytes32 _Hct_DiaEdu) onlyPnF public returns(bool){
        DiaEduStruct storage DECT = DiaEdufromHashLists[_Hct_DiaEdu];
        require(DECT.isupload);
        require(DECT.ispaid == false);
        Balance[msg.sender] = Balance[msg.sender].sub(DECT.fee);
        Balance[DECT.hcaddress] = Balance[DECT.hcaddress].add(DECT.fee);
        DECT.ispaid = true; 
        return true;
    }

    function CheckDECT(bytes32 _Hct_DiaEdu) view public returns(bool){
        return DiaEdufromHashLists[_Hct_DiaEdu].ispaid;
    }

}
