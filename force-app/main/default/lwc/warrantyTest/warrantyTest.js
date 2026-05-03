import { LightningElement, api } from 'lwc';

export default class WarrantyTest extends LightningElement {

    @api
    get value() { return this._value; }
    set value(v) {
        this._value = v;
        console.log('warrantyTest value received:', JSON.stringify(v));
    }
    _value;

    get vehicleName()    { return this._value?.vehicleName    || 'No data'; }
    get warrantyStatus() { return this._value?.warrantyStatus || 'No data'; }
}