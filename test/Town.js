const {
    BN,
    ether,
    expectRevert,
    time,
    balance,
} = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const Town = artifacts.require('Town');
const TownToken = artifacts.require('TownToken');
const ExternalToken = artifacts.require('ExternalTokenTemplate');

contract('Town test', async ([official, otherOfficial1, otherOfficial2, holder, otherHolder]) => {
    beforeEach(async () => {
        this.distributionPeriod = 24;

        this.externalToken = await ExternalToken.new(new BN('2000000000000000000000'), { from: official });
        this.totalSupply = new BN('500000000000000000000');
        this.townToken = await TownToken.new();
        this.initialRate = new BN('20000000000000');
        this.town = await Town.new(this.distributionPeriod, '10', this.initialRate, '1000000000000000000', '50', '10000000000000000000000',
            '100', this.townToken.address);
        await this.townToken.init(this.totalSupply, this.town.address);
    });

    it('checking the Town token parameters', async () => {
        expect(await this.townToken.name.call()).to.equal('Town Token');
        expect(await this.townToken.symbol.call()).to.equal('TTW');
        expect(await this.townToken.decimals.call()).to.be.bignumber.equal(new BN(18));
    });

    it('checking the Town contract parameters', async () => {
        expect(await this.townToken.balanceOf(this.town.address)).to.be.bignumber.equal(this.totalSupply);
    });

    it('call sendExternalTokens()', async () => {
        const tokensNumber = new BN(50);

        await this.externalToken.approve(this.town.address, tokensNumber, { from: official });
        await this.town.sendExternalTokens(official, this.externalToken.address, { from: official });
        expect(await this.externalToken.balanceOf(this.town.address)).to.be.bignumber.equal(tokensNumber);
        expect(await this.town.checkProposal.call(this.externalToken.address)).to.be.true;
    });

    it('FAIL: call sendExternalTokens()', async () => {
        await this.externalToken.approve(this.town.address, new BN('500000000000000000000'), { from: official });
        await this.externalToken.transfer(holder, new BN('2000000000000000000000'), { from: official });
        await expectRevert(this.town.sendExternalTokens(official, this.externalToken.address, { from: official }),
            'Official should have external tokens for approved');
    });

    it('call transfer() from the Town token holder', async () => {
        await this.town.send(ether('0.003'), { from: holder });
        expect(await this.townToken.balanceOf(holder)).to.be.bignumber.equal(new BN('150000000000000000000'));
        await this.townToken.transfer(otherHolder, new BN('100000000000000000000'), { from: holder });
        expect(await this.townToken.balanceOf(holder)).to.be.bignumber.equal(new BN('50000000000000000000'));
        expect(await this.townToken.balanceOf(otherHolder)).to.be.bignumber.equal(new BN('100000000000000000000'));
    });

    it('call getTownTokens() and checking the Town token holders', async () => {
        await this.town.getTownTokens(holder, { value: ether('0.003') });
        expect(await this.townToken.balanceOf(holder)).to.be.bignumber.equal(new BN('150000000000000000000'));
        expect(await this.townToken.getHoldersCount.call()).to.be.bignumber.equal(new BN(1));
        expect(await this.townToken.getHolderByIndex.call(0)).to.equal(holder);

        await this.townToken.transfer(otherHolder, new BN('100000000000000000000'), { from: holder });
        await this.town.getTownTokens(holder, { value: ether('0.0000001') });
        await this.town.getTownTokens(holder, { value: ether('0.003') });
        expect(await this.townToken.balanceOf(holder)).to.be.bignumber.equal(new BN('125000000000000000000'));

        const result = await this.town.getMyTownTokens.call({ from: holder });
        expect(result['0']).to.be.bignumber.equal(new BN('6000000000000000'));
        expect(result['1']).to.be.bignumber.equal(new BN('225000000000000000000'));
    });

    it('checking current rate and call IWantTakeTokensToAmount()', async () => {
        const value = ether('1');

        // expect(await this.town.getCurrentRate.call()).to.be.bignumber.equal(initialRate); // TODO: Invalid number of parameters for "getCurrentRate". Got 0 expected 1!
        expect(await this.town.IWantTakeTokensToAmount.call(value)).to.be.bignumber.equal(value.div(this.initialRate).mul(new BN('1000000000000000000')));
    });

    it('sending ether to the Town contract', async () => {
        await this.town.sendTransaction({ from: official, value: ether('1') });
        // expect(await this.town.getLengthRemunerationQueue.call()).to.be.bignumber.equal(new BN(0)); // TODO: Invalid number of parameters for "getLengthRemunerationQueue". Got 0 expected 1!
    });

    it('FAIL: call voteOn()', async () => {
        await expectRevert.unspecified(this.town.voteOn(this.externalToken.address, new BN(10)));
    });

    it('call claimExternalTokens()', async () => {
        await this.town.claimExternalTokens(holder, { from: official });
    });

    it('call remuneration()', async () => {
        await this.town.send(ether('0.003'), { from: holder });
        const townBalanceBeforeRefund = await balance.current(this.town.address);
        expect(townBalanceBeforeRefund).to.be.bignumber.equal(ether('0.003'));
        expect(await this.townToken.balanceOf(holder)).to.be.bignumber.equal(new BN('150000000000000000000'));

       // await this.townToken.transfer(this.town.address, new BN('100000000000000000000'), { from: holder });
        await this.townToken.approve(this.town.address, new BN('100000000000000000000'), { from: holder });
        await this.town.remuneration(new BN('100000000000000000000'), { from: holder });

        const townBalanceAfterRefund = await balance.current(this.town.address);
        expect(townBalanceBeforeRefund.sub(townBalanceAfterRefund)).to.be.bignumber.equal(ether('0.002'));

        const result = await this.town.getMyTownTokens.call({ from: holder });
        expect(result['0']).to.be.bignumber.equal(new BN('1000000000000000'));
        expect(result['1']).to.be.bignumber.equal(new BN('50000000000000000000'));
        expect(await this.townToken.balanceOf(holder)).to.be.bignumber.equal(new BN('50000000000000000000'));
    });

    it('call distributionSnapshot()', async () => {
        // send external tokens (2 proposals: 1k+1k, 8k tokens)
        await expectRevert(this.town.distributionSnapshot(), 'distribution time has not yet arrived');
        await this.externalToken.transfer(otherOfficial1, new BN('1000000000000000000000'), { from: official });
        const externalToken2 = await ExternalToken.new(new BN('8000000000000000000000'), { from: otherOfficial2 });

        await this.externalToken.approve(this.town.address, new BN('1000000000000000000000'), { from: official });
        await this.externalToken.approve(this.town.address, new BN('1000000000000000000000'), { from: otherOfficial1 });
        await externalToken2.approve(this.town.address, new BN('8000000000000000000000'), { from: otherOfficial2 });

        await this.town.sendExternalTokens(official, this.externalToken.address, { from: official });
        await this.town.sendExternalTokens(otherOfficial1, this.externalToken.address, { from: otherOfficial1 });
        await this.town.sendExternalTokens(otherOfficial2, externalToken2.address, { from: otherOfficial2 });

        // get tokens and vote to proposals
        await this.town.getTownTokens(holder, { value: ether('0.002') });
        expect(await this.townToken.balanceOf(holder)).to.be.bignumber.equal(new BN('100000000000000000000'));
        await this.town.getTownTokens(otherHolder, { value: ether('0.001') });
        expect(await this.townToken.balanceOf(otherHolder)).to.be.bignumber.equal(new BN('25000000000000000000'));
        await this.townToken.transfer(this.externalToken.address, new BN('50000000000000000000'), { from: holder });
        await this.townToken.transfer(externalToken2.address, new BN('12500000000000000000'), { from: otherHolder });

        const timeShift = 86400 - (await time.latest() % 86400);
        time.increase(timeShift);
        time.increase(time.duration.hours(this.distributionPeriod + 1));

        // distribution #1
        await this.town.distributionSnapshot();

        // officials can request payments
        expect(await balance.current(this.town.address)).to.be.bignumber.equal(ether('0.003'));

        await this.town.send(ether('0.00001'), { from: official });
        expect(await balance.current(this.town.address)).to.be.bignumber.equal(ether('0.00181'));
        await this.town.send(ether('0.00001'), { from: official }); // repeated request will be ignored
        expect(await balance.current(this.town.address)).to.be.bignumber.equal(ether('0.00182'));

        await this.town.send(ether('0.00001'), { from: otherOfficial1 });
        expect(await balance.current(this.town.address)).to.be.bignumber.equal(ether('0.00063'));

        await this.town.send(ether('0.00001'), { from: otherOfficial2 });
        expect(await balance.current(this.town.address)).to.be.bignumber.equal(ether('0.00004'));

        // voters can request external tokens
        await this.town.send(ether('0.00001'), { from: holder });
        expect(await this.externalToken.balanceOf(holder)).to.be.bignumber.equal(new BN('160000000000000000000'));
        expect(await externalToken2.balanceOf(holder)).to.be.bignumber.equal(new BN('640000000000000000000'));
        await this.town.send(ether('0.00001'), { from: holder }); // repeated request will be ignored
        expect(await this.externalToken.balanceOf(holder)).to.be.bignumber.equal(new BN('160000000000000000000'));
        expect(await externalToken2.balanceOf(holder)).to.be.bignumber.equal(new BN('640000000000000000000'));

        await this.town.send(ether('0.00001'), { from: otherHolder });
        expect(await this.externalToken.balanceOf(otherHolder)).to.be.bignumber.equal(new BN('40000000000000000000'));
        expect(await externalToken2.balanceOf(otherHolder)).to.be.bignumber.equal(new BN('160000000000000000000'));

        await expectRevert(this.town.distributionSnapshot(), 'distribution time has not yet arrived');

        // distribution #2
        time.increase(time.duration.hours(this.distributionPeriod));
        await this.town.distributionSnapshot();
        await this.town.send(ether('0.00001'), { from: holder });
        expect(await this.externalToken.balanceOf(holder)).to.be.bignumber.equal(new BN('320000000000000000000'));
        expect(await externalToken2.balanceOf(holder)).to.be.bignumber.equal(new BN('1280000000000000000000'));

        // distribution #3
        time.increase(time.duration.hours(this.distributionPeriod));
        await this.town.distributionSnapshot();
        await this.town.send(ether('0.00001'), { from: holder });
        expect(await this.externalToken.balanceOf(holder)).to.be.bignumber.equal(new BN('480000000000000000000'));
        expect(await externalToken2.balanceOf(holder)).to.be.bignumber.equal(new BN('1920000000000000000000'));

        await this.town.send(ether('0.00001'), { from: otherHolder });
        expect(await this.externalToken.balanceOf(otherHolder)).to.be.bignumber.equal(new BN('120000000000000000000'));
        expect(await externalToken2.balanceOf(otherHolder)).to.be.bignumber.equal(new BN('480000000000000000000'));


        // distribution #4 - #10
        time.increase(time.duration.hours(this.distributionPeriod * 10));
        await this.town.distributionSnapshot();
        await this.town.distributionSnapshot();
        await this.town.distributionSnapshot();
        await this.town.distributionSnapshot();
        await this.town.distributionSnapshot();
        await this.town.distributionSnapshot();
        await this.town.distributionSnapshot();

        await this.town.send(ether('0.00001'), { from: holder });
        expect(await this.externalToken.balanceOf(holder)).to.be.bignumber.equal(new BN('1600000000000000000000'));
        expect(await externalToken2.balanceOf(holder)).to.be.bignumber.equal(new BN('6400000000000000000000'));

        await this.town.send(ether('0.00001'), { from: otherHolder });
        expect(await this.externalToken.balanceOf(otherHolder)).to.be.bignumber.equal(new BN('400000000000000000000'));
        expect(await externalToken2.balanceOf(otherHolder)).to.be.bignumber.equal(new BN('1600000000000000000000'));

        // all tokens have been handed out. distribution #11 will have no effect
        await this.town.distributionSnapshot();
        await this.town.send(ether('0.00001'), { from: holder });
        expect(await this.externalToken.balanceOf(holder)).to.be.bignumber.equal(new BN('1600000000000000000000'));
        expect(await externalToken2.balanceOf(holder)).to.be.bignumber.equal(new BN('6400000000000000000000'));

        await this.town.send(ether('0.00001'), { from: official });
        expect(await balance.current(this.town.address)).to.be.bignumber.equal(ether('0.00014'));
    });

    it('call claimFunds()', async () => {
        await this.externalToken.approve(this.town.address, new BN(10), { from: official });
        await this.town.sendExternalTokens(official, this.externalToken.address, { from: official });
        await this.town.getTownTokens(holder, { value: ether('0.001') });

        const timeShift = 86400 - (await time.latest() % 86400);
        time.increase(timeShift);
        time.increase(time.duration.hours(this.distributionPeriod + 1));
        await this.town.distributionSnapshot();
        await this.townToken.transfer(this.externalToken.address, new BN(30), { from: holder });

        await this.externalToken.approve(this.town.address, new BN(300), { from: official });
        await this.town.sendExternalTokens(official, this.externalToken.address, { from: official });
        time.increase(time.duration.hours(this.distributionPeriod + 1));
        await this.town.distributionSnapshot();
        await this.town.claimFunds(official);
    });
});
