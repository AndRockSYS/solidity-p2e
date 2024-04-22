import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { time, loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

import deployVRFContracts from './deploy_vrf';
import { Roulette } from '../typechain-types';

type Bet = { player: string; betColor: number; amount: bigint };

describe('Roulette', () => {
    async function deployRoulette(generatorAddress: string): Promise<Roulette> {
        return await hre.ethers.deployContract('Roulette', [10, generatorAddress]);
    }

    async function makeABet(contract: Roulette, color: number, signer: any): Promise<Bet> {
        const oneEther = ethers.parseEther('1');

        await contract.connect(signer).enterRound(color, { value: oneEther, from: signer.address });

        return {
            player: signer.address,
            betColor: color,
            amount: oneEther,
        };
    }

    it('Should create only one round at the same time', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);
        const roulette = await deployRoulette(await generator.getAddress());

        await roulette.createRound();
        const currentRound = await roulette.rounds(0);

        expect(currentRound.timestamp).to.be.equal(await time.latest());

        await expect(roulette.createRound()).to.be.revertedWith('Current round is not closed');
    });

    it('Should be possible to enter the round only when it is opened', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);
        const roulette = await deployRoulette(await generator.getAddress());
        const [_owner, first, second, third] = await ethers.getSigners();

        await roulette.createRound();

        await makeABet(roulette, 1, first);
        await makeABet(roulette, 2, second);
        await makeABet(roulette, 3, third);

        const [_winningColor, _timestamp, blackPool, redPool, greenPool] = await roulette.rounds(0);

        expect(blackPool).to.be.equal(redPool);
        expect(redPool).to.be.equal(greenPool);
        expect(greenPool).to.be.equal(BigInt(ethers.parseEther('1')));

        await time.increase(61);

        await expect(makeABet(roulette, 1, first)).to.be.revertedWith('Round is closed');
    });

    it('Should send request for number only when the round is closed', async () => {
        const [_coordinator, generator] = await loadFixture(deployVRFContracts);
        const roulette = await deployRoulette(await generator.getAddress());

        await roulette.createRound();

        await generator.approve(await roulette.getAddress(), true);
        await expect(roulette.sendRequestForNumber()).to.be.revertedWith('Round is not closed');

        await time.increase(61);

        await roulette.sendRequestForNumber();

        expect(await roulette.currentRequestId()).to.be.not.equal(0);
    });

    it('Should close the round only when the number is generated', async () => {
        const [_owner, player] = await ethers.getSigners();

        const [coordinator, generator] = await loadFixture(deployVRFContracts);
        const roulette = await deployRoulette(await generator.getAddress());

        await roulette.createRound();
        await generator.approve(await roulette.getAddress(), true);

        const bet = await makeABet(roulette, 1, player);
        let black: Bet[] = [];
        black.push(bet);

        await time.increase(61);

        await roulette.sendRequestForNumber();

        await expect(roulette.closeRound(black, [], [])).to.be.revertedWith(
            'The request was not fulfilled'
        );

        const requestId = await roulette.currentRequestId();
        await coordinator.fulfillRandomWords(requestId, await generator.getAddress());

        await roulette.closeRound(black, [], []);

        const round = await roulette.rounds(0);
        expect(round.winningColor).to.not.be.equal(0);

        expect(await roulette.roundId()).to.be.equal(1);
    });

    it('Should get enough owner fee', async () => {
        const [_owner, player] = await ethers.getSigners();

        const [coordinator, generator] = await loadFixture(deployVRFContracts);
        const roulette = await deployRoulette(await generator.getAddress());

        await roulette.createRound();

        const blackBet = await makeABet(roulette, 1, player);
        const redBet = await makeABet(roulette, 2, player);

        const black = [blackBet];
        const red = [redBet];

        await time.increase(61);

        await generator.approve(await roulette.getAddress(), true);
        await roulette.sendRequestForNumber();

        const requestId = await roulette.currentRequestId();
        await coordinator.fulfillRandomWords(requestId, await generator.getAddress());

        await roulette.closeRound(black, red, []);

        const rouletteAddress = await roulette.getAddress();
        expect(await ethers.provider.getBalance(rouletteAddress)).to.be.equal(
            ethers.parseEther('2') / 10n
        );
    });

    it('Should distribute winning amount among people depending on their bets', async () => {
        const signers = await ethers.getSigners();

        const [coordinator, generator] = await loadFixture(deployVRFContracts);
        const roulette = await deployRoulette(await generator.getAddress());

        await roulette.createRound();

        let black: Bet[] = [];
        black.push(await makeABet(roulette, 1, signers[1]));
        black.push(await makeABet(roulette, 1, signers[2]));
        black.push(await makeABet(roulette, 1, signers[3]));
        black.push(await makeABet(roulette, 1, signers[4]));

        let red: Bet[] = [];
        red.push(await makeABet(roulette, 2, signers[5]));
        red.push(await makeABet(roulette, 2, signers[6]));
        red.push(await makeABet(roulette, 2, signers[7]));

        red.push(await makeABet(roulette, 2, signers[1]));
        red.push(await makeABet(roulette, 2, signers[2]));

        await time.increase(61);
        await generator.approve(await roulette.getAddress(), true);
        await roulette.sendRequestForNumber();
        const requestId = await roulette.currentRequestId();
        await coordinator.fulfillRandomWords(requestId, await generator.getAddress());

        let balancesBefore = [];
        for (let i = 0; i < 8; i++) {
            balancesBefore.push(await ethers.provider.getBalance(signers[i]));
        }

        await roulette.closeRound(black, red, []);

        //winnerColor will always be red

        let balancesAfter = [];
        for (let i = 0; i < 8; i++) {
            balancesAfter.push(await ethers.provider.getBalance(signers[i]));
        }

        const oneEther = ethers.parseEther('1');

        const totalPool = oneEther * 9n;
        const commision = (totalPool * 10n) / 100n;
        const winnerPool = oneEther * 5n;
        const prizePool = totalPool - winnerPool - commision;

        const perPerson = (prizePool * oneEther) / winnerPool + oneEther;

        expect(balancesAfter[5] - balancesBefore[5]).to.be.equal(perPerson);
        expect(balancesAfter[6] - balancesBefore[6]).to.be.equal(perPerson);
        expect(balancesAfter[7] - balancesBefore[7]).to.be.equal(perPerson);
        expect(balancesAfter[1] - balancesBefore[1]).to.be.equal(perPerson);
        expect(balancesAfter[2] - balancesBefore[2]).to.be.equal(perPerson);
    });
});
