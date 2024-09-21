1. mint
2. burn
3. transfer
4. randomize
5. buy
6. list
7. unlist
8. auction

- unlistNft bug
    If the Nft is in the itemIdToDetails array and then the owner transfers it to another wallet currently the now previous owner is still set to currentOwner meaning they can call unlistNft and transfer the nft back to themself.

daily completed:
- add natspec
- _completePurchase transferFrom parameter to should be _buyer instead of msg.sender
- write test to check _completePurchase fuction below works correctly
    specifically when msg.sender calling completeAuction function is the seller of the item and not the buyer



Dynamic artwork
Art by: Steve Johnson: https://www.pexels.com/@steve/
