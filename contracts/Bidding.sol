// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

contract Bidding {
    address public owner;
    uint256 public id = 0;
    RFQ[] public Requests;

    address[] tempAddr;
    uint256[] tmpScoreList;

    Indicator[] tempIndicator;

    struct RFQ { // request for qutation
        address owner;
        string productName;
        address[] suppliersEnroll;
        address[] suppliersSelected;
        address[] suppliersOfferEncryptedPrice;
        address[] suppliersAnnouncePrice;
        address[] suppliersValid;
        mapping (address => Supplier) suppliers;
        Indicator[] indicators;
        uint256[] priceScoreList;
        address winner;
    }

    struct Supplier {
        string supplierName;
        bool enroll;
        bool selected;
        bool priceOffered;
        bool priceAnnounced;
        bool priceValid;
        string priceCode;
        string encryptedPrice;
        uint256 price;
        uint256[] indicatorValueList;
        uint256 totalScore;
    }

    // indicator for product or service
    struct Indicator {
        string name;
        string unit;
        bool high2low;
        bool scoreReady;
        uint256[] scoreList;
        IndicatorSuppliersValue[] finalSuppliersValue;
    }

    struct IndicatorSuppliersValue {
        address supplier;
        uint256 value;
    }

    struct SupplierIndicatorScore {
        address supplier;
        IndicatorScore[] indicatorScore;
    }

    struct IndicatorScore {
        string name;
        uint256 value;
        uint256 score;
    }

    constructor() {
        owner = msg.sender;
    }

    // buyer request for qutation
    function createRFQ(
        string calldata productName,
        // Indicator[] calldata indicators   because conflux studio did support this kind of parameters splict the Indicator
        // uint256[] scoreList in indicator had to be set in another function
        string[] calldata indicatorName,
        string[] calldata indicatorUnit,
        bool[] calldata indicatorHigh2low,
        uint256[] calldata priceScoreList
    ) public payable {
        uint256 numberIndicator = indicatorName.length;
        require(indicatorUnit.length == numberIndicator,  "indicatorUnit length didn't match");
        require(indicatorHigh2low.length == numberIndicator,  "indicatorHigh2low length didn't match");
        Requests.push();
        RFQ storage request = Requests[id];
        id += 1;
        request.owner = msg.sender;
        request.productName = productName;
        request.priceScoreList = priceScoreList;
        for (uint i = 0; i < numberIndicator; i++) {
            //Indicator storage newIndicator;
            request.indicators.push();
            request.indicators[i].name = indicatorName[i];
            request.indicators[i].unit = indicatorUnit[i];
            request.indicators[i].high2low = indicatorHigh2low[i];
            request.indicators[i].scoreReady = false;
        }
    }

    function setScoreList(uint256 requestID, uint256 indicatorIndex, uint256[] calldata scoreList) public {
        require(msg.sender == Requests[requestID].owner, "unauthorized");
        for(uint i = 0; i < scoreList.length; i++) {
            Requests[requestID].indicators[indicatorIndex].scoreList.push(scoreList[i]);
        }
        Requests[requestID].indicators[indicatorIndex].scoreReady = true;
    }

    function enrollIn(uint256 requestID, string calldata supplierName, uint256[] calldata indicatorValueList) public {
        tempIndicator = Requests[requestID].indicators;
        require(tempIndicator.length == indicatorValueList.length, "indicatorValueList length is wrong");
        Requests[requestID].suppliersEnroll.push(msg.sender);
        Requests[requestID].suppliers[msg.sender].supplierName = supplierName;
        Requests[requestID].suppliers[msg.sender].enroll = true;
        for (uint i = 0; i < tempIndicator.length; i++) {
            Requests[requestID].suppliers[msg.sender].indicatorValueList.push(indicatorValueList[i]);
        }
    }

    function selectSuppliers(uint256 requestID, address[] calldata suppliers) public {
        require(msg.sender == Requests[requestID].owner, "unauthorized");
        for (uint i = 0; i < suppliers.length; i++) {
            require(Requests[requestID].suppliers[suppliers[i]].enroll, 'one supplier has not enrolled');            
            Requests[requestID].suppliersSelected.push(suppliers[i]);
            Requests[requestID].suppliers[suppliers[i]].selected =  true;
        }
    }

    function offerEncryptedPrice (uint256 requestID, string memory priceCode, string memory encryptedPrice) public {
        require(Requests[requestID].suppliers[msg.sender].selected, 'you are not selected by buyer');
        Requests[requestID].suppliers[msg.sender].priceCode = priceCode;
        Requests[requestID].suppliers[msg.sender].encryptedPrice = encryptedPrice;
        Requests[requestID].suppliersOfferEncryptedPrice.push(msg.sender);
        Requests[requestID].suppliers[msg.sender].priceOffered = true;
    }

    function announcePrice(uint256 requestID, uint256 price) public {
        require(Requests[requestID].suppliers[msg.sender].priceOffered, 'you have not offer encrypted price');
        Requests[requestID].suppliers[msg.sender].price = price;
        Requests[requestID].suppliersAnnouncePrice.push(msg.sender);
        Requests[requestID].suppliers[msg.sender].priceAnnounced = true;
    }
    
    // considering calculation on chain will cost a lot, we put price validation on the cloud side
    function buyerConfirmValidSuppliers(uint256 requestID, address[] calldata suppliers) public {
        require(msg.sender == Requests[requestID].owner, "unauthorized");
        for (uint i = 0; i < suppliers.length; i++) {
            require(Requests[requestID].suppliers[suppliers[i]].priceAnnounced, 'one supplier has not announce price');
            Requests[requestID].suppliersValid.push(suppliers[i]);
            Requests[requestID].suppliers[suppliers[i]].priceValid =  true;
        }
    }

    // considering calculation on chain will cost a lot, we put this calculation on the cloud side
    /*
    function compareScore(uint256 requestID) public {
        // prepare finalSuppliersValue
        address[] memory suppliersValid = Requests[requestID].suppliersValid;
        tempIndicator = Requests[requestID].indicators;
        for (uint j = 0; j < tempIndicator.length; j++) {
            Requests[requestID].indicators[j].finalSuppliersValue.push();
            for (uint i = 0; i < suppliersValid.length; i++) {
                Requests[requestID].indicators[j].finalSuppliersValue.push(IndicatorSuppliersValue({
                    supplier: suppliersValid[i],
                    value: Requests[requestID].suppliers[suppliersValid[i]].indicatorValueList[j]
                }));
            }
        }
        // calculate score
        for (uint j = 0; j < tempIndicator.length; j++) {
            //sortIndicator(tempIndicator[j].finalSuppliersValue);
            uint256 numberSupplierGotScore;
            if (tempIndicator[j].finalSuppliersValue.length >= tempIndicator[j].scoreList.length) {
                numberSupplierGotScore = tempIndicator[j].scoreList.length;
            } else {
                numberSupplierGotScore = tempIndicator[j].finalSuppliersValue.length;
            }
            for (uint i = 0; i < numberSupplierGotScore; i++) {
                address supplierAddres;
                supplierAddres = tempIndicator[j].finalSuppliersValue[i].supplier;
                if(tempIndicator[j].high2low) {
                    Requests[requestID].suppliers[supplierAddres].totalScore += tempIndicator[j].scoreList[numberSupplierGotScore-i-1];
                } else {
                    Requests[requestID].suppliers[supplierAddres].totalScore += tempIndicator[j].scoreList[i];
                }
            }
        }
        // find winner
        Supplier memory winnerSupplier;
        address winnerAddress;
        for (uint i = 0; i < suppliersValid.length; i++) {
            if (Requests[requestID].suppliers[suppliersValid[i]].totalScore > winnerSupplier.totalScore) {
                winnerSupplier = Requests[requestID].suppliers[suppliersValid[i]];
                winnerAddress = suppliersValid[i];
            }
        }
    }
    */

    function confirmWinner(uint256 requestID, address winner) public {
        require(msg.sender == Requests[requestID].owner, "unauthorized");
        Requests[requestID].winner = winner;
    }

    // getters
    function showWinner(uint256 requestID) external view returns (address) {
        return Requests[requestID].winner;
    }

    function showSupplierTotalsore(uint256 requestNumber, address supplier) external view returns (uint256) {
        return Requests[requestNumber].suppliers[supplier].totalScore;
    }

    function sortIndicator(IndicatorSuppliersValue [] storage array) internal{
        QuickSortIndicator(array, 0, array.length - 1);
    }
    
    function QuickSortIndicator(IndicatorSuppliersValue [] storage array, uint256 left, uint256 right) internal {
        uint256 i = left;
        uint256 j = right;
        // base
        if(i == j)
            return;
        uint256 pivot = array[ uint256(left + (right - left) / 2) ].value;
        while (i <= j) {           
            while (array[i].value < pivot) 
                i++;            
            while (pivot < array[j].value) 
                j--;           
            if (i <= j) {
                IndicatorSuppliersValue memory temp;
                temp.supplier = array[i].supplier;
                temp.value = array[i].value;
                array[i].supplier = array[j].supplier;
                array[i].value = array[j].value;
                array[j].supplier = temp.supplier;
                array[j].value = temp.value;
                //(array[i], array[j]) = (array[j], array[i]);
                i++;
                j--;
            }
        }        
        // branch 
        if (left < j)
            QuickSortIndicator(array, left, j);
        if (i < right)
            QuickSortIndicator(array, i, right);
    }

}