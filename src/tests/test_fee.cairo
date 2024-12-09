use betsy::bet::get_fee_amount;


#[test]
fn test_fee() {
    let fee = get_fee_amount(25, 100);
    assert_eq!(fee, 4);

    let fee = get_fee_amount(25, 1000);
    assert_eq!(fee, 50);

    let fee = get_fee_amount(25, 1);
    assert_eq!(fee, 0);
}
