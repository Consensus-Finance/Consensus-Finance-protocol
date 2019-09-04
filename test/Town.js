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

contract('Town test', async ([owner, official, holder]) => {
    beforeEach(async () => {
        this.distributionPeriod = 24;

        this.externalToken = await ExternalToken.new(new BN(1000), { from: official });
        this.totalSupply = new BN('500000000000000000000');
        this.townToken = await TownToken.new();
        this.initialRate = new BN('20000000000000');
        this.town = await Town.new(this.distributionPeriod, '12', this.initialRate, '100', '50', '10000000000000000000000',
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
        await this.externalToken.approve(this.town.address, new BN(500), { from: official });
        await this.externalToken.transfer(holder, new BN(1000), { from: official });
        await expectRevert(this.town.sendExternalTokens(official, this.externalToken.address, { from: official }),
            'Official should have external tokens for approved');
    });

    it('call transfer() from the Town token by owner', async () => {
        await this.externalToken.approve(this.town.address, new BN(10), { from: official });
        await this.town.sendExternalTokens(official, this.externalToken.address, { from: official });
        await this.townToken.transfer(this.externalToken.address, new BN(0), { from: owner });
        expect(await this.townToken.getHolderByIndex.call(0)).to.equal(this.externalToken.address);
    });

    it('FAIL: call transfer() from the Town token by not owner', async () => {
        await this.externalToken.approve(this.town.address, new BN(10), { from: official });
        await this.town.sendExternalTokens(official, this.externalToken.address, { from: official });
        await expectRevert(this.townToken.transfer(this.externalToken.address, new BN(10), { from: holder }),
            'SafeMath: subtraction overflow');
    });

    it('call getTownTokens() and checking the Town token holders', async () => {
        await this.town.getTownTokens(holder, { value: ether('0.003') });
        expect(await this.townToken.balanceOf(holder)).to.be.bignumber.equal(new BN('150000000000000000000'));
        expect(await this.townToken.getHoldersCount.call()).to.be.bignumber.equal(new BN(1));
        expect(await this.townToken.getHolderByIndex.call(0)).to.equal(holder);

        await this.townToken.transfer(this.town.address, new BN('100000000000000000000'), { from: holder });
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

    it('FAIL: call voteOn() by owner', async () => {
        await expectRevert.unspecified(this.town.voteOn(this.externalToken.address, new BN(10)));
    });

    it('call claimExternalTokens()', async () => {
        await this.town.claimExternalTokens(holder, { from: official });
    });

    it('call remuneration()', async () => {
        await expectRevert(this.town.remuneration(new BN(10), { from: holder }), 'Town tokens not found');
        await this.town.getTownTokens(holder, { value: ether('0.003') });
        await this.townToken.approve(this.town.address, new BN('100000000000000000000'), { from: holder });
        await expectRevert(this.town.remuneration(new BN('100000000000000000001'), { from: holder }),
            'Town tokens must be approved for town smart contract');
        const townBalanceBefore = await balance.current(this.town.address);
        await this.town.remuneration(new BN('100000000000000000000'), { from: holder });
        const townBalanceAfter = await balance.current(this.town.address);
        expect(townBalanceBefore.sub(townBalanceAfter)).to.be.bignumber.equal(ether('0.002'));

        const result = await this.town.getMyTownTokens.call({ from: holder });
        expect(result['0']).to.be.bignumber.equal(new BN('1000000000000000'));
        expect(result['1']).to.be.bignumber.equal(new BN('50000000000000000000'));
    });

    it('call distributionSnapshot()', async () => {
        await expectRevert(this.town.distributionSnapshot(), 'distribution time has not yet arrived');

        await this.externalToken.approve(this.town.address, new BN(50), { from: official });
        await this.town.sendExternalTokens(official, this.externalToken.address, { from: official });
        const timeShift = 86400 - (await time.latest() % 86400);
        time.increase(timeShift);
        time.increase(time.duration.hours(this.distributionPeriod + 1));
        await this.town.distributionSnapshot();
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
