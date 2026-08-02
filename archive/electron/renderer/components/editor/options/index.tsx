import LeftOptions from './left';
import RightOptions from './right';

const Options = () => {
  return (
    <div className="container">
      <LeftOptions/>
      <RightOptions/>
      <style jsx>{`
          .container {
            display: flex;
            padding: 0 16px;
            align-items: center;
            justify-content: space-between;
            width: 100%;
            background: var(--background-color);
            z-index: 99;
            height: 48px;
            flex: 0 0 48px;
            -webkit-app-region: no-drag;
            box-sizing: border-box;
          }
        `}</style>
    </div>
  );
};

export default Options;
